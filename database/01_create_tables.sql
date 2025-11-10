-- Load Shedding & Energy Monitoring System
-- Database Creation Script
-- File: 01_create_tables.sql

USE master;
GO

-- Create database if it doesn't exist
IF NOT EXISTS(SELECT name FROM sys.databases WHERE name = 'LoadSheddingEnergyDB')
BEGIN
    CREATE DATABASE LoadSheddingEnergyDB;
END
GO

USE grooot;
GO

-- Enable necessary features
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Regions Table - Stores geographical areas and municipalities
CREATE TABLE Regions (
    RegionID INT IDENTITY(1,1) PRIMARY KEY,
    RegionName NVARCHAR(100) NOT NULL,
    RegionCode NVARCHAR(20) UNIQUE NOT NULL,
    Municipality NVARCHAR(100),
    Province NVARCHAR(50),
    TimeZone NVARCHAR(50) DEFAULT 'SAST',
    Population INT,
    TotalCustomers INT,
    AverageConsumption DECIMAL(10,2),
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedDate DATETIME2 DEFAULT GETDATE(),
    
    CONSTRAINT CHK_RegionCode_Format CHECK (RegionCode LIKE '[A-Z][A-Z]-[0-9][0-9][0-9]'),
    CONSTRAINT CHK_Population_Positive CHECK (Population > 0),
    CONSTRAINT CHK_TotalCustomers_Positive CHECK (TotalCustomers > 0)
);

-- 2. Users Table - System users (households, businesses, admins, technicians)
CREATE TABLE Users (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(50) UNIQUE NOT NULL,
    Email NVARCHAR(100) UNIQUE NOT NULL,
    PasswordHash NVARCHAR(255) NOT NULL,
    PasswordSalt NVARCHAR(255) NOT NULL,
    UserType NVARCHAR(20) NOT NULL CHECK (UserType IN ('Admin', 'Household', 'Business', 'Technician', 'MunicipalAdmin')),
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    PhoneNumber NVARCHAR(20),
    AlternatePhone NVARCHAR(20),
    AddressLine1 NVARCHAR(255) NOT NULL,
    AddressLine2 NVARCHAR(255),
    City NVARCHAR(100) NOT NULL,
    PostalCode NVARCHAR(10),
    RegionID INT NOT NULL,
    MeterNumber NVARCHAR(50) UNIQUE,
    AccountNumber NVARCHAR(50) UNIQUE,
    IsVerified BIT DEFAULT 0,
    IsActive BIT DEFAULT 1,
    LastLogin DATETIME2,
    FailedLoginAttempts INT DEFAULT 0,
    AccountLockedUntil DATETIME2,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (RegionID) REFERENCES Regions(RegionID),
    CONSTRAINT CHK_Email_Format CHECK (Email LIKE '%_@__%.__%'),
    CONSTRAINT CHK_PhoneNumber_Format CHECK (PhoneNumber LIKE '+[0-9]%' OR PhoneNumber LIKE '0[0-9]%')
);
