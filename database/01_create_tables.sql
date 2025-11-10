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


-- 3. UserProfiles Table - Extended user information
CREATE TABLE UserProfiles (
    ProfileID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT UNIQUE NOT NULL,
    DateOfBirth DATE,
    IDNumber NVARCHAR(20),
    Occupation NVARCHAR(100),
    HouseholdSize INT DEFAULT 1,
    PropertyType NVARCHAR(20) CHECK (PropertyType IN ('House', 'Apartment', 'Business', 'Factory', 'Complex')),
    PropertySizeSqM DECIMAL(8,2),
    AverageMonthlyIncome DECIMAL(12,2),
    EnergyConsumptionAwareness NVARCHAR(10) CHECK (EnergyConsumptionAwareness IN ('Low', 'Medium', 'High')),
    HasElectricVehicle BIT DEFAULT 0,
    HasSolarPanels BIT DEFAULT 0,
    HasGenerator BIT DEFAULT 0,
    HasBatteryBackup BIT DEFAULT 0,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    CONSTRAINT CHK_HouseholdSize_Positive CHECK (HouseholdSize > 0),
    CONSTRAINT CHK_PropertySize_Positive CHECK (PropertySizeSqM > 0)
);

-- 4. Schedules Table - Load shedding schedules for each region
CREATE TABLE Schedules (
    ScheduleID INT IDENTITY(1,1) PRIMARY KEY,
    RegionID INT NOT NULL,
    Stage INT NOT NULL CHECK (Stage BETWEEN 1 AND 8),
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL,
    DayOfWeek INT CHECK (DayOfWeek BETWEEN 1 AND 7), -- 1=Sunday, 7=Saturday
    ScheduleDate DATE, -- For specific date schedules
    IsRecurring BIT DEFAULT 1,
    ScheduleType NVARCHAR(20) DEFAULT 'Normal' CHECK (ScheduleType IN ('Normal', 'Emergency', 'Maintenance')),
    DurationMinutes AS DATEDIFF(MINUTE, StartTime, EndTime),
    IsActive BIT DEFAULT 1,
    CreatedBy INT NOT NULL,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedDate DATETIME2 DEFAULT GETDATE(),
    EffectiveFrom DATE DEFAULT CAST(GETDATE() AS DATE),
    EffectiveTo DATE,
    
    FOREIGN KEY (RegionID) REFERENCES Regions(RegionID),
    FOREIGN KEY (CreatedBy) REFERENCES Users(UserID),
    CONSTRAINT CHK_StartTime_Before_EndTime CHECK (StartTime < EndTime),
    CONSTRAINT CHK_EffectiveDates CHECK (EffectiveFrom <= ISNULL(EffectiveTo, '9999-12-31'))
);

-- 5. PowerUsage Table - Records of electricity consumption
CREATE TABLE PowerUsage (
    UsageID BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    MeterReading DECIMAL(12,4) NOT NULL,
    UsageKWH DECIMAL(10,4) NOT NULL,
    Timestamp DATETIME2 NOT NULL,
    Temperature DECIMAL(5,2),
    Humidity DECIMAL(5,2),
    IsPeakHours BIT DEFAULT 0,
    IsLoadShedding BIT DEFAULT 0,
    CostPerKWH DECIMAL(8,4) DEFAULT 2.50,
    TotalCost DECIMAL(10,2),
    ApparentPower DECIMAL(8,2), -- kVA
    PowerFactor DECIMAL(3,2) DEFAULT 0.95,
    Voltage DECIMAL(6,2) DEFAULT 230.0,
    CurrentReading DECIMAL(8,2),
    DataSource NVARCHAR(20) DEFAULT 'SmartMeter' CHECK (DataSource IN ('SmartMeter', 'Manual', 'Estimate', 'API')),
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    CONSTRAINT CHK_UsageKWH_Positive CHECK (UsageKWH >= 0),
    CONSTRAINT CHK_MeterReading_Positive CHECK (MeterReading >= 0),
    CONSTRAINT CHK_PowerFactor_Range CHECK (PowerFactor BETWEEN 0.5 AND 1.0)
);

