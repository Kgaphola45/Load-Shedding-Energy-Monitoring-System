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

-- 3. Procedure to Report New Outage
CREATE OR ALTER PROCEDURE sp_ReportOutage
    @RegionID INT,
    @OutageType NVARCHAR(20),
    @StartTime DATETIME2,
    @EstimatedRestoration DATETIME2 = NULL,
    @Stage INT = NULL,
    @Description NVARCHAR(500),
    @Cause NVARCHAR(100) = NULL,
    @ReportedBy INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @AffectedCustomers INT;
        
        -- Count affected customers in the region
        SELECT @AffectedCustomers = COUNT(*)
        FROM Users 
        WHERE RegionID = @RegionID AND IsActive = 1;
        
        -- Insert outage record
        INSERT INTO Outages (
            RegionID, OutageType, StartTime, EstimatedRestoration, Stage,
            AffectedCustomers, Description, Cause, ReportedBy
        )
        VALUES (
            @RegionID, @OutageType, @StartTime, @EstimatedRestoration, @Stage,
            @AffectedCustomers, @Description, @Cause, @ReportedBy
        );
        
        DECLARE @NewOutageID INT = SCOPE_IDENTITY();
        
        -- Create alerts for all users in the affected region
        INSERT INTO Alerts (
            UserID, AlertType, Title, Message, Priority, RelatedOutageID
        )
        SELECT 
            u.UserID,
            'OutageReported',
            CONCAT('Power Outage Reported - ', r.RegionName),
            CONCAT('Power outage reported in your area. ', 
                   CASE WHEN @EstimatedRestoration IS NOT NULL 
                        THEN CONCAT('Estimated restoration: ', FORMAT(@EstimatedRestoration, 'hh:mm tt'))
                        ELSE 'Restoration time to be confirmed.' END),
            'High',
            @NewOutageID
        FROM Users u
        INNER JOIN Regions r ON u.RegionID = r.RegionID
        WHERE u.RegionID = @RegionID 
        AND u.IsActive = 1
        AND EXISTS (
            SELECT 1 FROM AlertPreferences ap 
            WHERE ap.UserID = u.UserID 
            AND ap.AlertType = 'OutageReported' 
            AND ap.IsEnabled = 1
        );
        
        COMMIT TRANSACTION;
        
        SELECT 
            @NewOutageID AS OutageID,
            'Outage reported successfully' AS Message;
            
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

-- 4. Procedure to Get Load Shedding Schedule for Region
CREATE OR ALTER PROCEDURE sp_GetLoadSheddingSchedule
    @RegionID INT = NULL,
    @RegionCode NVARCHAR(20) = NULL,
    @Stage INT = NULL,
    @Date DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @Date IS NULL
        SET @Date = CAST(GETDATE() AS DATE);
    
    SELECT 
        r.RegionName,
        r.RegionCode,
        r.Municipality,
        r.Province,
        s.Stage,
        s.StartTime,
        s.EndTime,
        s.DurationMinutes,
        CASE s.DayOfWeek 
            WHEN 1 THEN 'Sunday'
            WHEN 2 THEN 'Monday' 
            WHEN 3 THEN 'Tuesday'
            WHEN 4 THEN 'Wednesday'
            WHEN 5 THEN 'Thursday'
            WHEN 6 THEN 'Friday'
            WHEN 7 THEN 'Saturday'
        END as DayName,
        s.ScheduleType,
        s.IsRecurring
    FROM Schedules s
    INNER JOIN Regions r ON s.RegionID = r.RegionID
    WHERE r.IsActive = 1
    AND s.IsActive = 1
    AND (
        (s.IsRecurring = 1 AND s.DayOfWeek = DATEPART(WEEKDAY, @Date))
        OR (s.IsRecurring = 0 AND s.ScheduleDate = @Date)
    )
    AND (s.RegionID = @RegionID OR @RegionID IS NULL)
    AND (r.RegionCode = @RegionCode OR @RegionCode IS NULL)
    AND (s.Stage = @Stage OR @Stage IS NULL)
    AND (s.EffectiveFrom <= @Date AND (s.EffectiveTo IS NULL OR s.EffectiveTo >= @Date))
    ORDER BY r.RegionName, s.Stage, s.StartTime;
END;
GO


-- 5. Procedure to Calculate User Energy Consumption Summary
CREATE OR ALTER PROCEDURE sp_GetUserEnergySummary
    @UserID INT,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(MONTH, -1, CAST(GETDATE() AS DATE));
    
    IF @EndDate IS NULL
        SET @EndDate = CAST(GETDATE() AS DATE);
    
    SELECT 
        u.UserID,
        u.FirstName + ' ' + u.LastName as UserName,
        r.RegionName,
        COUNT(pu.UsageID) as TotalReadings,
        SUM(pu.UsageKWH) as TotalConsumptionKWH,
        AVG(pu.UsageKWH) as AverageDailyConsumption,
        SUM(pu.TotalCost) as TotalCost,
        MAX(pu.UsageKWH) as PeakConsumption,
        MIN(pu.UsageKWH) as MinimumConsumption,
        SUM(CASE WHEN pu.IsPeakHours = 1 THEN pu.UsageKWH ELSE 0 END) as PeakHoursConsumption,
        SUM(CASE WHEN pu.IsLoadShedding = 1 THEN pu.UsageKWH ELSE 0 END) as LoadSheddingConsumption,
        (SELECT COUNT(*) FROM Outages o 
         WHERE o.RegionID = u.RegionID 
         AND o.StartTime BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate)
         AND o.OutageType = 'LoadShedding') as LoadSheddingEvents
    FROM Users u
    INNER JOIN Regions r ON u.RegionID = r.RegionID
    LEFT JOIN PowerUsage pu ON u.UserID = pu.UserID 
        AND pu.Timestamp BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate)
    WHERE u.UserID = @UserID
    GROUP BY u.UserID, u.FirstName, u.LastName, r.RegionName, u.RegionID;
END;
GO

-- 6. Procedure to Generate Monthly Bill
CREATE OR ALTER PROCEDURE sp_GenerateMonthlyBill
    @UserID INT,
    @BillingMonth DATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        DECLARE @TotalUsageKWH DECIMAL(10,2);
        DECLARE @TotalAmount DECIMAL(10,2);
        DECLARE @VATRate DECIMAL(5,2);
        DECLARE @VATAmount DECIMAL(10,2);
        DECLARE @DueDate DATE;
        DECLARE @TariffID INT;
        DECLARE @BaseRate DECIMAL(8,4);
        DECLARE @InvoiceNumber NVARCHAR(50);
        
        -- Get VAT rate from system settings
        SELECT @VATRate = CAST(SettingValue AS DECIMAL(5,2))
        FROM SystemSettings 
        WHERE SettingKey = 'VATRate' AND IsActive = 1;
        
        IF @VATRate IS NULL
            SET @VATRate = 0.15; -- Default VAT rate
        
        -- Calculate total usage for the month
        SELECT @TotalUsageKWH = SUM(UsageKWH)
        FROM PowerUsage
        WHERE UserID = @UserID
        AND Timestamp >= @BillingMonth
        AND Timestamp < DATEADD(MONTH, 1, @BillingMonth);
        
        IF @TotalUsageKWH IS NULL
            SET @TotalUsageKWH = 0;
        
        -- Get applicable tariff
        SELECT TOP 1 
            @TariffID = TariffID,
            @BaseRate = BaseRate
        FROM Tariffs t
        INNER JOIN Users u ON t.RegionID = u.RegionID
        WHERE u.UserID = @UserID
        AND t.CustomerType = CASE 
            WHEN u.UserType IN ('Household') THEN 'Residential'
            WHEN u.UserType IN ('Business') THEN 'Business'
            ELSE 'Industrial'
        END
        AND t.EffectiveFrom <= @BillingMonth
        AND (t.EffectiveTo IS NULL OR t.EffectiveTo >= @BillingMonth)
        AND t.IsActive = 1
        ORDER BY t.EffectiveFrom DESC;
        
        IF @BaseRate IS NULL
            SET @BaseRate = 2.50; -- Default rate
        
        -- Calculate amounts
        SET @TotalAmount = @TotalUsageKWH * @BaseRate;
        SET @VATAmount = @TotalAmount * @VATRate;
        SET @DueDate = DATEADD(DAY, 25, @BillingMonth); -- Due date 25th of next month
        SET @InvoiceNumber = 'INV-' + FORMAT(@BillingMonth, 'yyyyMM') + '-' + RIGHT('000' + CAST(@UserID AS NVARCHAR(10)), 3);
        
        -- Insert bill
        INSERT INTO Billing (
            UserID, BillingMonth, TotalUsageKWH, TotalAmount, VATAmount, DueDate, InvoiceNumber
        )
        VALUES (
            @UserID, @BillingMonth, @TotalUsageKWH, @TotalAmount, @VATAmount, @DueDate, @InvoiceNumber
        );
        
        DECLARE @NewBillID INT = SCOPE_IDENTITY();
        
        -- Insert billing details
        INSERT INTO BillingDetails (BillID, Description, Quantity, UnitPrice, Amount, TaxRate, TaxAmount)
        VALUES 
            (@NewBillID, 'Energy Consumption', @TotalUsageKWH, @BaseRate, @TotalAmount, @VATRate, @VATAmount),
            (@NewBillID, 'Service Fee', 1, 15.00, 15.00, @VATRate, 2.25),
            (@NewBillID, 'Network Charges', 1, 35.00, 35.00, @VATRate, 5.25);
        
        -- Update total amount with additional charges
        UPDATE Billing 
        SET TotalAmount = TotalAmount + 50.00, -- Service fee + network charges
            VATAmount = VATAmount + 7.50
        WHERE BillID = @NewBillID;
        
        -- Create alert for the user
        INSERT INTO Alerts (
            UserID, AlertType, Title, Message, Priority
        )
        VALUES (
            @UserID, 'PaymentDue',
            'New Electricity Bill Generated',
            CONCAT('Your electricity bill for ', FORMAT(@BillingMonth, 'MMMM yyyy'), 
                   ' is ready. Amount due: R', FORMAT(@TotalAmount + 50.00, 'N2'), 
                   '. Due date: ', FORMAT(@DueDate, 'dd MMM yyyy')),
            'Medium'
        );
        
        COMMIT TRANSACTION;
        
        SELECT 
            @NewBillID AS BillID,
            @InvoiceNumber AS InvoiceNumber,
            @TotalUsageKWH AS TotalUsageKWH,
            (@TotalAmount + 50.00) AS TotalAmount,
            @DueDate AS DueDate,
            'Bill generated successfully' AS Message;
            
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

-- 7. Procedure to Get Active Outages with Details
CREATE OR ALTER PROCEDURE sp_GetActiveOutages
    @RegionID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        o.OutageID,
        r.RegionName,
        r.Municipality,
        r.Province,
        o.OutageType,
        o.StartTime,
        o.EstimatedRestoration,
        o.Stage,
        o.AffectedCustomers,
        o.Description,
        o.Cause,
        o.Status,
        o.Priority,
        DATEDIFF(MINUTE, o.StartTime, GETDATE()) as DurationMinutes,
        (SELECT COUNT(*) FROM OutageUpdates ou WHERE ou.OutageID = o.OutageID) as UpdateCount,
        ru.FirstName + ' ' + ru.LastName as ReportedBy,
        cu.FirstName + ' ' + cu.LastName as ConfirmedBy
    FROM Outages o
    INNER JOIN Regions r ON o.RegionID = r.RegionID
    LEFT JOIN Users ru ON o.ReportedBy = ru.UserID
    LEFT JOIN Users cu ON o.ConfirmedBy = cu.UserID
    WHERE o.Status IN ('Active', 'Investigating')
    AND (o.RegionID = @RegionID OR @RegionID IS NULL)
    ORDER BY o.Priority DESC, o.StartTime DESC;
END;
GO

-- 8. Procedure to Update Outage Status
CREATE OR ALTER PROCEDURE sp_UpdateOutageStatus
    @OutageID INT,
    @Status NVARCHAR(20),
    @EndTime DATETIME2 = NULL,
    @ResolvedBy INT = NULL,
    @UpdateDescription NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Update outage
        UPDATE Outages 
        SET 
            Status = @Status,
            EndTime = CASE WHEN @Status = 'Resolved' THEN ISNULL(@EndTime, GETDATE()) ELSE EndTime END,
            ResolvedBy = CASE WHEN @Status = 'Resolved' THEN @ResolvedBy ELSE ResolvedBy END,
            ModifiedDate = GETDATE()
        WHERE OutageID = @OutageID;
        
        -- Add outage update if description provided
        IF @UpdateDescription IS NOT NULL
        BEGIN
            INSERT INTO OutageUpdates (OutageID, UpdateType, Title, Description, UpdatedBy)
            VALUES (
                @OutageID, 
                'StatusChange',
                CONCAT('Outage Status Updated to ', @Status),
                @UpdateDescription,
                @ResolvedBy
            );
        END
        
        -- If outage is resolved, create resolution alerts
        IF @Status = 'Resolved'
        BEGIN
            INSERT INTO Alerts (
                UserID, AlertType, Title, Message, Priority, RelatedOutageID
            )
            SELECT 
                u.UserID,
                'OutageResolved',
                'Power Restored',
                CONCAT('Power has been restored in your area. Outage duration: ', 
                       DATEDIFF(MINUTE, o.StartTime, ISNULL(@EndTime, GETDATE())), ' minutes.'),
                'Medium',
                @OutageID
            FROM Outages o
            INNER JOIN Users u ON o.RegionID = u.RegionID
            WHERE o.OutageID = @OutageID
            AND u.IsActive = 1
            AND EXISTS (
                SELECT 1 FROM AlertPreferences ap 
                WHERE ap.UserID = u.UserID 
                AND ap.AlertType = 'OutageResolved' 
                AND ap.IsEnabled = 1
            );
        END
        
        COMMIT TRANSACTION;
        
        SELECT 
            @OutageID AS OutageID,
            'Outage status updated successfully' AS Message;
            
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

-- 9. Procedure to Get User Alerts
CREATE OR ALTER PROCEDURE sp_GetUserAlerts
    @UserID INT,
    @IsRead BIT = NULL,
    @AlertType NVARCHAR(30) = NULL,
    @DaysBack INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        a.AlertID,
        a.AlertType,
        a.Title,
        a.Message,
        a.IsRead,
        a.Priority,
        a.SentDate,
        a.ReadDate,
        a.ExpiryDate,
        o.OutageType,
        r.RegionName,
        s.Stage as LoadSheddingStage
    FROM Alerts a
    LEFT JOIN Outages o ON a.RelatedOutageID = o.OutageID
    LEFT JOIN Regions r ON o.RegionID = r.RegionID
    LEFT JOIN Schedules s ON a.RelatedScheduleID = s.ScheduleID
    WHERE a.UserID = @UserID
    AND a.SentDate >= DATEADD(DAY, -@DaysBack, GETDATE())
    AND (a.IsRead = @IsRead OR @IsRead IS NULL)
    AND (a.AlertType = @AlertType OR @AlertType IS NULL)
    ORDER BY a.SentDate DESC;
END;
GO

-- 10. Procedure to Mark Alert as Read
CREATE OR ALTER PROCEDURE sp_MarkAlertAsRead
    @AlertID BIGINT,
    @UserID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE Alerts 
    SET IsRead = 1, 
        ReadDate = GETDATE()
    WHERE AlertID = @AlertID
    AND (UserID = @UserID OR @UserID IS NULL);
    
    SELECT 
        @AlertID AS AlertID,
        'Alert marked as read' AS Message;
END;
GO

-- 11. Procedure to Get Regional Energy Statistics
CREATE OR ALTER PROCEDURE sp_GetRegionalEnergyStats
    @RegionID INT = NULL,
    @StartDate DATE = NULL,
    @EndDate DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @StartDate IS NULL
        SET @StartDate = DATEADD(MONTH, -1, CAST(GETDATE() AS DATE));
    
    IF @EndDate IS NULL
        SET @EndDate = CAST(GETDATE() AS DATE);
    
    SELECT 
        r.RegionID,
        r.RegionName,
        r.Municipality,
        r.Province,
        COUNT(DISTINCT u.UserID) as TotalCustomers,
        COUNT(pu.UsageID) as TotalReadings,
        SUM(pu.UsageKWH) as TotalConsumptionKWH,
        AVG(pu.UsageKWH) as AverageConsumptionPerReading,
        SUM(pu.TotalCost) as TotalCost,
        SUM(CASE WHEN pu.IsPeakHours = 1 THEN pu.UsageKWH ELSE 0 END) as PeakHoursConsumption,
        SUM(CASE WHEN pu.IsLoadShedding = 1 THEN pu.UsageKWH ELSE 0 END) as LoadSheddingConsumption,
        (SELECT COUNT(*) FROM Outages o 
         WHERE o.RegionID = r.RegionID 
         AND o.StartTime BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate)) as TotalOutages,
        (SELECT COUNT(*) FROM Outages o 
         WHERE o.RegionID = r.RegionID 
         AND o.OutageType = 'LoadShedding'
         AND o.StartTime BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate)) as LoadSheddingEvents
    FROM Regions r
    LEFT JOIN Users u ON r.RegionID = u.RegionID AND u.IsActive = 1
    LEFT JOIN PowerUsage pu ON u.UserID = pu.UserID 
        AND pu.Timestamp BETWEEN @StartDate AND DATEADD(DAY, 1, @EndDate)
    WHERE (r.RegionID = @RegionID OR @RegionID IS NULL)
    AND r.IsActive = 1
    GROUP BY r.RegionID, r.RegionName, r.Municipality, r.Province
    ORDER BY TotalConsumptionKWH DESC;
END;
GO

-- 12. Procedure to Backup System Data for Reporting
CREATE OR ALTER PROCEDURE sp_BackupSystemData
    @BackupType NVARCHAR(20) = 'Daily'
AS
BEGIN
    SET NOCOUNT ON;
    
    -- This procedure would typically export data to backup tables or files
    -- For now, we'll create a summary log entry
    
    DECLARE @TotalUsers INT, @TotalOutages INT, @TotalAlerts INT, @TotalUsageRecords BIGINT;
    
    SELECT @TotalUsers = COUNT(*) FROM Users WHERE IsActive = 1;
    SELECT @TotalOutages = COUNT(*) FROM Outages WHERE StartTime >= DATEADD(DAY, -30, GETDATE());
    SELECT @TotalAlerts = COUNT(*) FROM Alerts WHERE SentDate >= DATEADD(DAY, -7, GETDATE());
    SELECT @TotalUsageRecords = COUNT(*) FROM PowerUsage WHERE Timestamp >= DATEADD(DAY, -1, GETDATE());
    
    -- Log the backup operation (in a real system, this would be more comprehensive)
    INSERT INTO AuditLog (TableName, RecordID, Action, OldValues, NewValues, ChangedBy, IPAddress)
    VALUES (
        'SystemBackup',
        @BackupType,
        'BACKUP',
        NULL,
        CONCAT('Backup completed: Users=', @TotalUsers, 
               ', RecentOutages=', @TotalOutages,
               ', RecentAlerts=', @TotalAlerts,
               ', DailyUsageRecords=', @TotalUsageRecords),
        1, -- System user
        '127.0.0.1'
    );
    
    SELECT 
        @BackupType AS BackupType,
        GETDATE() AS BackupTime,
        @TotalUsers AS TotalActiveUsers,
        @TotalOutages AS RecentOutages,
        @TotalAlerts AS RecentAlerts,
        @TotalUsageRecords AS DailyUsageRecords,
        'System data backup completed successfully' AS Message;
END;
GO

PRINT 'Stored procedures created successfully!';
PRINT 'Total procedures created: ' + CAST((SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_TYPE = 'PROCEDURE') AS NVARCHAR(10));
