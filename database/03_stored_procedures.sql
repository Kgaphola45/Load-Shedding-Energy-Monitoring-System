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