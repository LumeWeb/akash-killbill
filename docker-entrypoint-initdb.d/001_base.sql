-- Create and configure Kill Bill database
CREATE DATABASE IF NOT EXISTS killbill 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

-- Ensure proper charset and collation even if database existed
ALTER DATABASE killbill 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

-- Switch to Kill Bill database
USE killbill;

-- Ensure proper table defaults
SET SESSION character_set_client = utf8mb4;
SET SESSION character_set_connection = utf8mb4;
SET SESSION character_set_results = utf8mb4;

-- Kill Bill core tables
CREATE TABLE IF NOT EXISTS accounts (
    id varchar(36) NOT NULL,
    external_key varchar(255) NOT NULL,
    email varchar(128) DEFAULT NULL,
    name varchar(100) DEFAULT NULL,
    first_name_length int DEFAULT NULL,
    currency varchar(3) DEFAULT NULL,
    billing_cycle_day_local int DEFAULT NULL,
    payment_method_id varchar(36) DEFAULT NULL,
    time_zone varchar(50) DEFAULT NULL,
    locale varchar(5) DEFAULT NULL,
    address1 varchar(100) DEFAULT NULL,
    address2 varchar(100) DEFAULT NULL,
    company_name varchar(50) DEFAULT NULL,
    city varchar(50) DEFAULT NULL,
    state_or_province varchar(50) DEFAULT NULL,
    country varchar(50) DEFAULT NULL,
    postal_code varchar(16) DEFAULT NULL,
    phone varchar(25) DEFAULT NULL,
    notes varchar(4096) DEFAULT NULL,
    migrated boolean DEFAULT false,
    created_date datetime NOT NULL,
    created_by varchar(50) NOT NULL,
    updated_date datetime DEFAULT NULL,
    updated_by varchar(50) DEFAULT NULL,
    tenant_record_id bigint NOT NULL,
    PRIMARY KEY(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
