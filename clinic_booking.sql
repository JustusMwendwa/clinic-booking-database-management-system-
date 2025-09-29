

-- Drop and create database
DROP DATABASE IF EXISTS clinic_booking;
CREATE DATABASE clinic_booking
  CHARACTER SET = 'utf8mb4'
  COLLATE = 'utf8mb4_general_ci';
USE clinic_booking;

-- ---------------------------------------------------------
-- Table: patients
-- ---------------------------------------------------------
CREATE TABLE patients (
    patient_id     INT AUTO_INCREMENT PRIMARY KEY,
    first_name     VARCHAR(50)  NOT NULL,
    last_name      VARCHAR(50)  NOT NULL,
    gender         ENUM('Male','Female','Other') NOT NULL,
    dob            DATE         NOT NULL,
    phone          VARCHAR(20)  NOT NULL UNIQUE,
    email          VARCHAR(100) UNIQUE,
    address        VARCHAR(255),
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: doctors
-- ---------------------------------------------------------
CREATE TABLE doctors (
    doctor_id      INT AUTO_INCREMENT PRIMARY KEY,
    first_name     VARCHAR(50) NOT NULL,
    last_name      VARCHAR(50) NOT NULL,
    specialization VARCHAR(100) NOT NULL,
    phone          VARCHAR(20) NOT NULL UNIQUE,
    email          VARCHAR(100) NOT NULL UNIQUE,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: rooms
-- ---------------------------------------------------------
CREATE TABLE rooms (
    room_id   INT AUTO_INCREMENT PRIMARY KEY,
    room_name VARCHAR(50) NOT NULL UNIQUE,
    location  VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: services
-- ---------------------------------------------------------
CREATE TABLE services (
    service_id   INT AUTO_INCREMENT PRIMARY KEY,
    name         VARCHAR(100) NOT NULL UNIQUE,
    description  TEXT,
    price        DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: appointments
-- Notes:
--  - appointment_datetime stores the scheduled start time
--  - unique_doctor_time prevents exact duplicate bookings for same doctor/time
--  - room_id is nullable (telemedicine / unassigned)
-- ---------------------------------------------------------
CREATE TABLE appointments (
    appointment_id   INT AUTO_INCREMENT PRIMARY KEY,
    patient_id       INT NOT NULL,
    doctor_id        INT NOT NULL,
    room_id          INT DEFAULT NULL,
    appointment_datetime DATETIME NOT NULL,
    duration_minutes  INT NOT NULL DEFAULT 30 CHECK (duration_minutes > 0),
    status           ENUM('Scheduled','Completed','Cancelled') DEFAULT 'Scheduled',
    notes            TEXT,
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (room_id) REFERENCES rooms(room_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    -- Prevent exact duplicate time-slot for same doctor
    UNIQUE KEY unique_doctor_time (doctor_id, appointment_datetime),
    -- Indexes to speed common queries
    INDEX idx_appointment_datetime (appointment_datetime),
    INDEX idx_patient_id (patient_id),
    INDEX idx_doctor_id (doctor_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: appointment_services (Many-to-Many)
-- ---------------------------------------------------------
CREATE TABLE appointment_services (
    appointment_id INT NOT NULL,
    service_id     INT NOT NULL,
    quantity       INT DEFAULT 1 CHECK (quantity > 0),
    PRIMARY KEY (appointment_id, service_id),
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (service_id) REFERENCES services(service_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Table: payments (One-to-One with appointment)
-- ---------------------------------------------------------
CREATE TABLE payments (
    payment_id     INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id INT NOT NULL UNIQUE,
    amount         DECIMAL(10,2) NOT NULL CHECK (amount >= 0),
    method         ENUM('Cash','Card','MobileMoney','Insurance') NOT NULL,
    status         ENUM('Pending','Paid','Refunded') DEFAULT 'Pending',
    paid_at        DATETIME DEFAULT NULL,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------
--  audit_logs (simple audit trail)
-- ---------------------------------------------------------
CREATE TABLE audit_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    entity VARCHAR(50) NOT NULL,
    entity_id INT,
    action VARCHAR(50) NOT NULL,
    performed_by VARCHAR(100),
    detail TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------
-- Views: convenience queries
--  - upcoming_appointments: next 30 days
--  - appointment_billing: appointment totals (sum of services)
-- ---------------------------------------------------------
CREATE OR REPLACE VIEW upcoming_appointments AS
SELECT
  a.appointment_id,
  a.appointment_datetime,
  a.duration_minutes,
  a.status,
  p.patient_id, CONCAT(p.first_name, ' ', p.last_name) AS patient_name, p.phone AS patient_phone,
  d.doctor_id, CONCAT(d.first_name, ' ', d.last_name) AS doctor_name, d.specialization,
  r.room_id, r.room_name
FROM appointments a
JOIN patients p ON a.patient_id = p.patient_id
JOIN doctors d ON a.doctor_id = d.doctor_id
LEFT JOIN rooms r ON a.room_id = r.room_id
WHERE a.appointment_datetime >= NOW()
ORDER BY a.appointment_datetime;

CREATE OR REPLACE VIEW appointment_billing AS
SELECT
  a.appointment_id,
  a.appointment_datetime,
  a.patient_id,
  a.doctor_id,
  COALESCE(SUM(s.price * aps.quantity), 0) AS services_total,
  COALESCE(pay.amount, 0) AS payment_amount,
  pay.status AS payment_status
FROM appointments a
LEFT JOIN appointment_services aps ON a.appointment_id = aps.appointment_id
LEFT JOIN services s ON aps.service_id = s.service_id
LEFT JOIN payments pay ON a.appointment_id = pay.appointment_id
GROUP BY a.appointment_id, pay.payment_id;

-- ---------------------------------------------------------
-- insert data
-- ---------------------------------------------------------
INSERT INTO doctors (first_name,last_name,specialization,phone,email)
VALUES
 ('Alice','Mwangi','General Practitioner','+254700111222','alice.mwangi@clinic.com'),
 ('John','Kimani','Dermatologist','+254700222333','john.kimani@clinic.com'),
 ('Grace','Nduta','Pediatrician','+254700333444','grace.nduta@clinic.com');

INSERT INTO patients (first_name,last_name,gender,dob,phone,email,address)
VALUES
 ('Mary','Otieno','Female','1990-05-12','+254711111111','mary.otieno@example.com','Nairobi'),
 ('Peter','Waweru','Male','1985-09-20','+254722222222','peter.waweru@example.com','Nairobi'),
 ('Susan','Achieng','Female','1995-03-03','+254733333333','susan.achieng@example.com','Nairobi');

INSERT INTO rooms (room_name,location)
VALUES ('Consultation 1','Ground Floor'),
       ('Consultation 2','Ground Floor'),
       ('Telemedicine','Online');

INSERT INTO services (name,description,price)
VALUES ('General Consultation','Basic health consultation',1500.00),
       ('Skin Treatment','Dermatology treatment',3000.00),
       ('Pediatric Checkup','Child health consultation',1800.00),
       ('Blood Test','Standard blood panel',1200.00);

-- Create  appointments (ensure appointment_datetime values do not conflict)
INSERT INTO appointments (patient_id, doctor_id, room_id, appointment_datetime, duration_minutes, status, notes)
VALUES
 (1, 1, 1, '2025-10-01 09:00:00', 30, 'Scheduled', 'First visit'),
 (2, 2, 2, '2025-10-01 10:00:00', 45, 'Scheduled', 'Follow-up skin check'),
 (3, 3, 3, '2025-10-02 11:30:00', 30, 'Scheduled', 'Pediatric consultation');

-- Link services to appointments
INSERT INTO appointment_services (appointment_id, service_id, quantity)
VALUES
 (1, 1, 1), -- Appointment 1: General Consultation
 (2, 2, 1), -- Appointment 2: Skin Treatment
 (3, 3, 1), -- Appointment 3: Pediatric Checkup
 (1, 4, 1); -- Appointment 1 also has Blood Test

--  payments
INSERT INTO payments (appointment_id, amount, method, status, paid_at)
VALUES
 (1, 2700.00, 'Card', 'Paid', '2025-09-25 14:00:00'),
 (2, 3000.00, 'Cash', 'Pending', NULL);


