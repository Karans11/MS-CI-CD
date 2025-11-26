-- Intentionally Vulnerable Database Schema for FakeBanking
-- This creates a database with PII data stored in plaintext
-- For CNAPP/Wiz Security Testing

CREATE DATABASE IF NOT EXISTS users;
USE users;

-- Drop table if exists
DROP TABLE IF EXISTS users;

-- Create users table with PII fields (intentionally insecure)
CREATE TABLE users (
    user_id VARCHAR(50) PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,  -- Storing passwords in plaintext!
    email VARCHAR(255) NOT NULL,
    ssn VARCHAR(11),                 -- PII: Social Security Number
    date_of_birth DATE,              -- PII: Date of Birth
    credit_card VARCHAR(19),         -- PII: Credit Card Number
    cvv VARCHAR(4),                  -- Sensitive: CVV
    balance DECIMAL(15, 2) DEFAULT 0.00,
    account_status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP NULL
);

-- Insert test users with intentionally exposed PII data
INSERT INTO users (user_id, username, password, email, ssn, date_of_birth, credit_card, cvv, balance) VALUES
('USER10001', 'admin', 'admin123', 'admin@fakebanking.com', '123-45-6789', '1980-01-15', '4532-1234-5678-9010', '123', 50000.00),
('USER10002', 'john.doe', 'password123', 'john.doe@email.com', '234-56-7890', '1985-03-22', '5500-0000-0000-0004', '456', 12500.75),
('USER10003', 'jane.smith', 'jane2024', 'jane.smith@email.com', '345-67-8901', '1990-07-10', '4111-1111-1111-1111', '789', 8750.50),
('USER10004', 'bob.johnson', 'bob123456', 'bob.j@email.com', '456-78-9012', '1978-11-30', '3782-822463-10005', '321', 25000.00),
('USER10005', 'alice.williams', 'alicepass', 'alice.w@email.com', '567-89-0123', '1992-05-18', '6011-0009-9013-9424', '654', 5600.25),
('USER10006', 'charlie.brown', 'charlie99', 'charlie.b@email.com', '678-90-1234', '1988-09-25', '3056-930902-5904', '987', 15750.00),
('USER10007', 'david.miller', 'david@123', 'david.m@email.com', '789-01-2345', '1995-02-14', '5105-1051-0510-5100', '246', 9800.00),
('USER10008', 'emma.davis', 'emma2024!', 'emma.d@email.com', '890-12-3456', '1987-12-05', '4012-8888-8888-1881', '135', 18900.50),
('USER10009', 'frank.wilson', 'frank789', 'frank.w@email.com', '901-23-4567', '1983-06-20', '3714-496353-98431', '802', 7250.75),
('USER10010', 'grace.moore', 'grace456', 'grace.m@email.com', '012-34-5678', '1991-08-12', '6011-1111-1111-1117', '579', 22000.00);

-- Create transactions table (for demo)
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    transaction_type VARCHAR(20) NOT NULL,
    amount DECIMAL(15, 2) NOT NULL,
    recipient VARCHAR(100),
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'completed',
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Insert sample transactions
INSERT INTO transactions (transaction_id, user_id, transaction_type, amount, recipient) VALUES
('TXN10001', 'USER10001', 'transfer', 500.00, 'USER10002'),
('TXN10002', 'USER10002', 'deposit', 1000.00, NULL),
('TXN10003', 'USER10003', 'withdrawal', 250.50, NULL),
('TXN10004', 'USER10001', 'payment', 150.00, 'Electric Company'),
('TXN10005', 'USER10004', 'transfer', 2000.00, 'USER10005'),
('TXN10006', 'USER10006', 'deposit', 5000.00, NULL),
('TXN10007', 'USER10007', 'payment', 75.25, 'Internet Provider'),
('TXN10008', 'USER10008', 'withdrawal', 500.00, NULL),
('TXN10009', 'USER10009', 'transfer', 300.00, 'USER10010'),
('TXN10010', 'USER10010', 'payment', 1200.00, 'Rent');

-- Create accounts table with more sensitive data
CREATE TABLE IF NOT EXISTS accounts (
    account_id VARCHAR(50) PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    account_type VARCHAR(50) NOT NULL,
    account_number VARCHAR(20) NOT NULL,  -- PII: Account Number
    routing_number VARCHAR(9) NOT NULL,   -- PII: Routing Number
    account_balance DECIMAL(15, 2) DEFAULT 0.00,
    interest_rate DECIMAL(5, 2) DEFAULT 0.00,
    overdraft_limit DECIMAL(15, 2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- Insert sample accounts
INSERT INTO accounts (account_id, user_id, account_type, account_number, routing_number, account_balance, interest_rate, overdraft_limit) VALUES
('ACC10001', 'USER10001', 'checking', '1234567890123456', '021000021', 50000.00, 0.01, 1000.00),
('ACC10002', 'USER10001', 'savings', '6543210987654321', '021000021', 25000.00, 2.50, 0.00),
('ACC10003', 'USER10002', 'checking', '1111222233334444', '026009593', 12500.75, 0.01, 500.00),
('ACC10004', 'USER10003', 'savings', '5555666677778888', '011401533', 8750.50, 2.00, 0.00),
('ACC10005', 'USER10004', 'checking', '9999888877776666', '122105155', 25000.00, 0.01, 2000.00),
('ACC10006', 'USER10005', 'checking', '1234123412341234', '091000019', 5600.25, 0.01, 250.00),
('ACC10007', 'USER10006', 'savings', '9876987698769876', '021000021', 15750.00, 2.25, 0.00),
('ACC10008', 'USER10007', 'checking', '5678567856785678', '111000025', 9800.00, 0.01, 750.00),
('ACC10009', 'USER10008', 'checking', '4321432143214321', '061000104', 18900.50, 0.01, 1500.00),
('ACC10010', 'USER10009', 'savings', '1357135713571357', '121000248', 7250.75, 1.75, 0.00);

-- Create admin users table (intentionally insecure)
CREATE TABLE IF NOT EXISTS admin_users (
    admin_id VARCHAR(50) PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,  -- Plaintext password
    role VARCHAR(50) NOT NULL,
    api_key VARCHAR(255),            -- Exposed API key
    last_login TIMESTAMP NULL
);

-- Insert admin users with hardcoded credentials
INSERT INTO admin_users (admin_id, username, password, role, api_key) VALUES
('ADMIN001', 'superadmin', 'SuperAdmin123!', 'super_admin', 'sk-admin-super-secret-key-99999'),
('ADMIN002', 'dbadmin', 'DbAdmin456!', 'database_admin', 'sk-admin-db-key-88888'),
('ADMIN003', 'sysadmin', 'SysAdmin789!', 'system_admin', 'sk-admin-sys-key-77777');

-- Display counts
SELECT 'Users created:' as Info, COUNT(*) as Count FROM users;
SELECT 'Transactions created:' as Info, COUNT(*) as Count FROM transactions;
SELECT 'Accounts created:' as Info, COUNT(*) as Count FROM accounts;
SELECT 'Admin users created:' as Info, COUNT(*) as Count FROM admin_users;

-- Show sample user data (intentionally exposing PII)
SELECT 'Sample user data with PII:' as Info;
SELECT user_id, username, password, email, ssn, credit_card, cvv, balance FROM users LIMIT 3;

-- Security Notes (for documentation):
-- WARNING: This database schema contains the following security issues:
-- 1. Passwords stored in plaintext (should be hashed with bcrypt/argon2)
-- 2. PII data (SSN, credit cards, CVV) stored unencrypted
-- 3. No data access controls or encryption at rest
-- 4. Weak password requirements
-- 5. No password expiration or rotation policy
-- 6. Admin credentials hardcoded
-- 7. API keys stored in plaintext
-- 8. No audit logging for sensitive data access
-- 9. Direct exposure of account numbers and routing numbers
-- 10. No multi-factor authentication support
