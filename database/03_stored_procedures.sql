-- Load Shedding & Energy Monitoring System
-- Stored Procedures Script
USE LoadSheddingEnergyDB;
GO

PRINT 'Creating stored procedures...';

-- 1. Procedure to Add New User with Profile
CREATE OR ALTER PROCEDURE sp_AddUserWithProfile
    @Username NVARCHAR(50),
    @Email NVARCHAR(100),
    @PasswordHash NVARCHAR(255),
    @PasswordSalt NVARCHAR(255),
    @UserType NVARCHAR(20),
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @PhoneNumber NVARCHAR(20),
    @AddressLine1 NVARCHAR(255),
    @City NVARCHAR(100),
    @RegionID INT,
    @MeterNumber NVARCHAR(50) = NULL,
    @HouseholdSize INT = 1,
    @PropertyType NVARCHAR(20) = 'House',
    @PropertySizeSqM DECIMAL(8,2) = NULL,
    @Occupation NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Insert into Users table
        INSERT INTO Users (
            Username, Email, PasswordHash, PasswordSalt, UserType,
            FirstName, LastName, PhoneNumber, AddressLine1, City, RegionID, MeterNumber
        )
        VALUES (
            @Username, @Email, @PasswordHash, @PasswordSalt, @UserType,
            @FirstName, @LastName, @PhoneNumber, @AddressLine1, @City, @RegionID, @MeterNumber
        );
        
        DECLARE @NewUserID INT = SCOPE_IDENTITY();
        
        -- Insert into UserProfiles table
        INSERT INTO UserProfiles (
            UserID, HouseholdSize, PropertyType, PropertySizeSqM, Occupation
        )
        VALUES (
            @NewUserID, @HouseholdSize, @PropertyType, @PropertySizeSqM, @Occupation
        );
        
        -- Set default alert preferences
        INSERT INTO AlertPreferences (UserID, AlertType, Channel, IsEnabled)
        VALUES 
            (@NewUserID, 'LoadSheddingStart', 'Both', 1),
            (@NewUserID, 'LoadSheddingEnd', 'SMS', 1),
            (@NewUserID, 'OutageReported', 'Both', 1),
            (@NewUserID, 'HighUsage', 'Email', 1);
        
        COMMIT TRANSACTION;
        
        SELECT 
            @NewUserID AS UserID,
            'User created successfully' AS Message;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO


-- 2. Procedure to Record Power Usage
CREATE OR ALTER PROCEDURE sp_RecordPowerUsage
    @UserID INT,
    @MeterReading DECIMAL(12,4),
    @UsageKWH DECIMAL(10,4),
    @Timestamp DATETIME2,
    @Temperature DECIMAL(5,2) = NULL,
    @Voltage DECIMAL(6,2) = 230.0,
    @CurrentReading DECIMAL(8,2) = NULL,
    @DataSource NVARCHAR(20) = 'SmartMeter'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @CostPerKWH DECIMAL(8,4);
        DECLARE @IsPeakHours BIT = 0;
        DECLARE @IsLoadShedding BIT = 0;
        
        -- Get user's tariff rate
        SELECT TOP 1 @CostPerKWH = t.BaseRate
        FROM Users u
        INNER JOIN Tariffs t ON u.RegionID = t.RegionID 
            AND t.CustomerType = CASE 
                WHEN u.UserType IN ('Household') THEN 'Residential'
                WHEN u.UserType IN ('Business') THEN 'Business'
                ELSE 'Industrial'
            END
        WHERE u.UserID = @UserID
        ORDER BY t.EffectiveFrom DESC;
        
        -- Set default cost if not found
        IF @CostPerKWH IS NULL
            SET @CostPerKWH = 2.50;
        
        -- Check if it's peak hours
        IF DATEPART(HOUR, @Timestamp) BETWEEN 18 AND 20
            SET @IsPeakHours = 1;
        
        -- Check if there's active load shedding for this user's region
        IF EXISTS (
            SELECT 1 
            FROM Outages o
            INNER JOIN Users u ON o.RegionID = u.RegionID
            WHERE u.UserID = @UserID 
            AND o.OutageType = 'LoadShedding'
            AND o.Status = 'Active'
            AND @Timestamp BETWEEN o.StartTime AND ISNULL(o.EndTime, GETDATE())
        )
            SET @IsLoadShedding = 1;
        
        -- Insert power usage record
        INSERT INTO PowerUsage (
            UserID, MeterReading, UsageKWH, Timestamp, Temperature,
            IsPeakHours, IsLoadShedding, CostPerKWH, TotalCost,
            Voltage, CurrentReading, DataSource
        )
        VALUES (
            @UserID, @MeterReading, @UsageKWH, @Timestamp, @Temperature,
            @IsPeakHours, @IsLoadShedding, @CostPerKWH, (@UsageKWH * @CostPerKWH),
            @Voltage, @CurrentReading, @DataSource
        );
        
        -- Check for high usage alert
        IF @UsageKWH > 10.0 -- Threshold for high usage
        BEGIN
            INSERT INTO Alerts (
                UserID, AlertType, Title, Message, Priority
            )
            VALUES (
                @UserID, 'HighUsage', 
                'High Energy Usage Detected',
                CONCAT('Your current energy usage (', @UsageKWH, ' kWh) is above normal levels. Consider reducing consumption during peak hours.'),
                'Medium'
            );
        END
        
        SELECT 
            SCOPE_IDENTITY() AS UsageID,
            'Power usage recorded successfully' AS Message;
            
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO
