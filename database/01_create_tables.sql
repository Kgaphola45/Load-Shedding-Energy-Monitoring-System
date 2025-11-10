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

-- 6. Outages Table - Logs of power interruptions
CREATE TABLE Outages (
    OutageID INT IDENTITY(1,1) PRIMARY KEY,
    RegionID INT NOT NULL,
    OutageType NVARCHAR(20) NOT NULL CHECK (OutageType IN ('Planned', 'Unplanned', 'LoadShedding', 'Maintenance', 'Fault', 'Weather')),
    StartTime DATETIME2 NOT NULL,
    EndTime DATETIME2,
    EstimatedRestoration DATETIME2,
    Stage INT, -- For load shedding
    AffectedCustomers INT,
    Description NVARCHAR(500),
    Cause NVARCHAR(100),
    Status NVARCHAR(20) DEFAULT 'Active' CHECK (Status IN ('Active', 'Resolved', 'Cancelled', 'Investigating')),
    Priority NVARCHAR(10) DEFAULT 'Medium' CHECK (Priority IN ('Low', 'Medium', 'High', 'Critical')),
    ReportedBy INT,
    ConfirmedBy INT,
    ResolvedBy INT,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (RegionID) REFERENCES Regions(RegionID),
    FOREIGN KEY (ReportedBy) REFERENCES Users(UserID),
    FOREIGN KEY (ConfirmedBy) REFERENCES Users(UserID),
    FOREIGN KEY (ResolvedBy) REFERENCES Users(UserID),
    CONSTRAINT CHK_StartTime_Before_EndTime_Outage CHECK (StartTime < ISNULL(EndTime, '9999-12-31')),
    CONSTRAINT CHK_AffectedCustomers_Positive CHECK (AffectedCustomers >= 0)
);

-- 7. OutageUpdates Table - Track updates for ongoing outages
CREATE TABLE OutageUpdates (
    UpdateID INT IDENTITY(1,1) PRIMARY KEY,
    OutageID INT NOT NULL,
    UpdateType NVARCHAR(20) CHECK (UpdateType IN ('StatusChange', 'ETAUpdate', 'CauseIdentified', 'ProgressUpdate', 'Resolution')),
    Title NVARCHAR(200) NOT NULL,
    Description NVARCHAR(1000) NOT NULL,
    UpdatedBy INT NOT NULL,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (OutageID) REFERENCES Outages(OutageID),
    FOREIGN KEY (UpdatedBy) REFERENCES Users(UserID)
);

-- 8. BackupSystems Table - Tracks backup power sources
CREATE TABLE BackupSystems (
    BackupID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    BackupType NVARCHAR(20) NOT NULL CHECK (BackupType IN ('Solar', 'Battery', 'Generator', 'UPS', 'Hybrid', 'Inverter')),
    SystemCapacityKWH DECIMAL(8,2) NOT NULL,
    SystemCapacityKW DECIMAL(8,2) NOT NULL,
    Manufacturer NVARCHAR(100),
    Model NVARCHAR(100),
    SerialNumber NVARCHAR(100),
    InstallationDate DATE NOT NULL,
    WarrantyExpiry DATE,
    IsActive BIT DEFAULT 1,
    LastMaintenanceDate DATE,
    NextMaintenanceDate DATE,
    MaintenanceIntervalDays INT DEFAULT 180,
    FuelType NVARCHAR(20) CHECK (FuelType IN ('Diesel', 'Petrol', 'Gas', 'None', 'Electric')),
    BatteryCapacityAH DECIMAL(8,2),
    SolarPanelCount INT,
    SolarPanelWattage DECIMAL(6,2),
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    CONSTRAINT CHK_SystemCapacity_Positive CHECK (SystemCapacityKWH > 0 AND SystemCapacityKW > 0),
    CONSTRAINT CHK_InstallationDate_Past CHECK (InstallationDate <= CAST(GETDATE() AS DATE))
);

-- 9. BackupUsage Table - Tracks backup system usage
CREATE TABLE BackupUsage (
    BackupUsageID BIGINT IDENTITY(1,1) PRIMARY KEY,
    BackupID INT NOT NULL,
    PowerGeneratedKWH DECIMAL(8,4) NOT NULL,
    PowerUsedKWH DECIMAL(8,4) NOT NULL,
    PowerStoredKWH DECIMAL(8,4),
    BatteryLevelPercent DECIMAL(5,2) CHECK (BatteryLevelPercent BETWEEN 0 AND 100),
    GeneratorRunningHours DECIMAL(6,2),
    FuelLevelPercent DECIMAL(5,2),
    Timestamp DATETIME2 NOT NULL,
    AmbientTemperature DECIMAL(5,2),
    SystemEfficiency DECIMAL(5,2),
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (BackupID) REFERENCES BackupSystems(BackupID),
    CONSTRAINT CHK_PowerGenerated_Positive CHECK (PowerGeneratedKWH >= 0),
    CONSTRAINT CHK_PowerUsed_Positive CHECK (PowerUsedKWH >= 0)
);

-- 10. Alerts Table - Notifications sent to users
CREATE TABLE Alerts (
    AlertID BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    AlertType NVARCHAR(30) NOT NULL CHECK (AlertType IN (
        'LoadSheddingStart', 'LoadSheddingEnd', 
        'OutageReported', 'OutageResolved', 'OutageUpdate',
        'HighUsage', 'UsageThreshold', 'MaintenanceReminder',
        'BackupSystemActive', 'BackupSystemLow', 'SystemAlert',
        'PaymentDue', 'TariffChange', 'Emergency'
    )),
    Title NVARCHAR(200) NOT NULL,
    Message NVARCHAR(1000) NOT NULL,
    IsRead BIT DEFAULT 0,
    IsSent BIT DEFAULT 0,
    Priority NVARCHAR(10) DEFAULT 'Medium' CHECK (Priority IN ('Low', 'Medium', 'High', 'Critical')),
    RelatedOutageID INT,
    RelatedScheduleID INT,
    RelatedUsageID BIGINT,
    SentDate DATETIME2 DEFAULT GETDATE(),
    ReadDate DATETIME2,
    ExpiryDate DATETIME2,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    FOREIGN KEY (RelatedOutageID) REFERENCES Outages(OutageID),
    FOREIGN KEY (RelatedScheduleID) REFERENCES Schedules(ScheduleID),
    FOREIGN KEY (RelatedUsageID) REFERENCES PowerUsage(UsageID)
);

-- 11. AlertPreferences Table - User preferences for alerts
CREATE TABLE AlertPreferences (
    PreferenceID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    AlertType NVARCHAR(30) NOT NULL,
    Channel NVARCHAR(20) DEFAULT 'Email' CHECK (Channel IN ('Email', 'SMS', 'Push', 'Both')),
    IsEnabled BIT DEFAULT 1,
    MinimumPriority NVARCHAR(10) DEFAULT 'Medium',
    QuietHoursStart TIME DEFAULT '22:00',
    QuietHoursEnd TIME DEFAULT '07:00',
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    UNIQUE (UserID, AlertType),
    CONSTRAINT CHK_QuietHours CHECK (QuietHoursStart < QuietHoursEnd)
);

-- 12. MaintenanceLogs Table - Equipment maintenance history
CREATE TABLE MaintenanceLogs (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    BackupID INT NOT NULL,
    MaintenanceType NVARCHAR(20) CHECK (MaintenanceType IN ('Routine', 'Repair', 'Inspection', 'Upgrade', 'Replacement')),
    Description NVARCHAR(500) NOT NULL,
    PerformedBy NVARCHAR(100) NOT NULL,
    PerformedDate DATE NOT NULL,
    NextMaintenanceDate DATE,
    Cost DECIMAL(10,2),
    PartsReplaced NVARCHAR(500),
    WorkHours DECIMAL(4,2),
    TechnicianNotes NVARCHAR(1000),
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (BackupID) REFERENCES BackupSystems(BackupID),
    CONSTRAINT CHK_Cost_Positive CHECK (Cost >= 0),
    CONSTRAINT CHK_WorkHours_Positive CHECK (WorkHours >= 0)
);

-- 13. Tariffs Table - Electricity pricing structure
CREATE TABLE Tariffs (
    TariffID INT IDENTITY(1,1) PRIMARY KEY,
    TariffName NVARCHAR(100) NOT NULL,
    TariffCode NVARCHAR(20) UNIQUE NOT NULL,
    RegionID INT NOT NULL,
    CustomerType NVARCHAR(20) DEFAULT 'Residential' CHECK (CustomerType IN ('Residential', 'Business', 'Industrial')),
    BaseRate DECIMAL(8,4) NOT NULL,
    PeakRate DECIMAL(8,4),
    OffPeakRate DECIMAL(8,4),
    WeekendRate DECIMAL(8,4),
    PeakHoursStart TIME DEFAULT '18:00',
    PeakHoursEnd TIME DEFAULT '20:00',
    EffectiveFrom DATE NOT NULL,
    EffectiveTo DATE,
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (RegionID) REFERENCES Regions(RegionID),
    CONSTRAINT CHK_BaseRate_Positive CHECK (BaseRate > 0),
    CONSTRAINT CHK_EffectiveDates_Tariff CHECK (EffectiveFrom <= ISNULL(EffectiveTo, '9999-12-31'))
);

-- 14. Billing Table - Customer billing information
CREATE TABLE Billing (
    BillID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    BillingMonth DATE NOT NULL,
    TotalUsageKWH DECIMAL(10,2) NOT NULL,
    TotalAmount DECIMAL(10,2) NOT NULL,
    VATAmount DECIMAL(10,2),
    DueDate DATE NOT NULL,
    PaymentStatus NVARCHAR(20) DEFAULT 'Pending' CHECK (PaymentStatus IN ('Pending', 'Paid', 'Overdue', 'Cancelled')),
    PaidDate DATE,
    PaymentMethod NVARCHAR(20),
    InvoiceNumber NVARCHAR(50) UNIQUE,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    CONSTRAINT CHK_TotalUsage_Positive CHECK (TotalUsageKWH >= 0),
    CONSTRAINT CHK_TotalAmount_Positive CHECK (TotalAmount >= 0),
    CONSTRAINT CHK_DueDate_After_BillingMonth CHECK (DueDate > BillingMonth)
);

-- 15. BillingDetails Table - Line items for each bill
CREATE TABLE BillingDetails (
    BillDetailID BIGINT IDENTITY(1,1) PRIMARY KEY,
    BillID INT NOT NULL,
    Description NVARCHAR(200) NOT NULL,
    Quantity DECIMAL(10,2) NOT NULL,
    UnitPrice DECIMAL(8,4) NOT NULL,
    Amount DECIMAL(10,2) NOT NULL,
    TaxRate DECIMAL(5,2) DEFAULT 0.15,
    TaxAmount DECIMAL(10,2),
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (BillID) REFERENCES Billing(BillID),
    CONSTRAINT CHK_Quantity_Positive CHECK (Quantity >= 0),
    CONSTRAINT CHK_UnitPrice_Positive CHECK (UnitPrice >= 0)
);

-- 16. EnergyGoals Table - User-set energy consumption targets
CREATE TABLE EnergyGoals (
    GoalID INT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    GoalType NVARCHAR(20) CHECK (GoalType IN ('Daily', 'Weekly', 'Monthly', 'Yearly')),
    TargetKWH DECIMAL(8,2) NOT NULL,
    TargetCost DECIMAL(8,2),
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    CurrentProgressKWH DECIMAL(8,2) DEFAULT 0,
    CurrentProgressCost DECIMAL(8,2) DEFAULT 0,
    IsAchieved BIT DEFAULT 0,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedDate DATETIME2 DEFAULT GETDATE(),
    
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    CONSTRAINT CHK_TargetKWH_Positive CHECK (TargetKWH > 0),
    CONSTRAINT CHK_EndDate_After_StartDate CHECK (EndDate > StartDate)
);

-- 17. NotificationsLog Table - Audit trail for all notifications sent
CREATE TABLE NotificationsLog (
    NotificationID BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserID INT NOT NULL,
    NotificationType NVARCHAR(30) NOT NULL,
    Channel NVARCHAR(20) NOT NULL,
    Subject NVARCHAR(200),
    Message NVARCHAR(1000) NOT NULL,
    Status NVARCHAR(20) DEFAULT 'Sent' CHECK (Status IN ('Sent', 'Delivered', 'Failed', 'Read')),
    ErrorMessage NVARCHAR(500),
    SentDate DATETIME2 DEFAULT GETDATE(),
    DeliveredDate DATETIME2,
    
    FOREIGN KEY (UserID) REFERENCES Users(UserID)
);

-- 18. SystemSettings Table - Application configuration
CREATE TABLE SystemSettings (
    SettingID INT IDENTITY(1,1) PRIMARY KEY,
    SettingKey NVARCHAR(50) UNIQUE NOT NULL,
    SettingValue NVARCHAR(500) NOT NULL,
    SettingType NVARCHAR(20) DEFAULT 'String' CHECK (SettingType IN ('String', 'Number', 'Boolean', 'JSON')),
    Description NVARCHAR(200),
    IsActive BIT DEFAULT 1,
    CreatedDate DATETIME2 DEFAULT GETDATE(),
    ModifiedDate DATETIME2 DEFAULT GETDATE()
);

-- 19. AuditLog Table - System audit trail
CREATE TABLE AuditLog (
    AuditID BIGINT IDENTITY(1,1) PRIMARY KEY,
    TableName NVARCHAR(50) NOT NULL,
    RecordID NVARCHAR(50) NOT NULL,
    Action NVARCHAR(10) NOT NULL CHECK (Action IN ('INSERT', 'UPDATE', 'DELETE')),
    OldValues NVARCHAR(MAX),
    NewValues NVARCHAR(MAX),
    ChangedBy INT,
    ChangedDate DATETIME2 DEFAULT GETDATE(),
    IPAddress NVARCHAR(45),
    UserAgent NVARCHAR(500),
    
    FOREIGN KEY (ChangedBy) REFERENCES Users(UserID)
);
