

USE LoadSheddingEnergyDB;
GO

PRINT 'Inserting sample data with South African information...';

-- 1. Insert Regions (municipalities and provinces)
PRINT 'Inserting Regions...';
INSERT INTO Regions (RegionName, RegionCode, Municipality, Province, Population, TotalCustomers, AverageConsumption)
VALUES 
    ('Johannesburg Central', 'JC-001', 'City of Johannesburg', 'Gauteng', 800000, 250000, 450.50),
    ('Cape Town Southern', 'CT-002', 'City of Cape Town', 'Western Cape', 600000, 180000, 380.75),
    ('Durban Coastal', 'DB-003', 'eThekwini Metropolitan', 'KwaZulu-Natal', 750000, 220000, 420.25),
    ('Pretoria North', 'PT-004', 'City of Tshwane', 'Gauteng', 450000, 140000, 510.80),
    ('Soweto', 'SW-005', 'City of Johannesburg', 'Gauteng', 1200000, 350000, 280.30),
    ('Khayelitsha', 'KH-006', 'City of Cape Town', 'Western Cape', 550000, 160000, 195.75),
    ('Port Elizabeth Central', 'PE-007', 'Nelson Mandela Bay', 'Eastern Cape', 350000, 95000, 365.40),
    ('Bloemfontein', 'BF-008', 'Mangaung Metropolitan', 'Free State', 280000, 75000, 395.60),
    ('Polokwane', 'PL-009', 'Polokwane Local Municipality', 'Limpopo', 220000, 60000, 325.90),
    ('Nelspruit', 'NS-010', 'Mbombela Local Municipality', 'Mpumalanga', 180000, 48000, 410.20);

-- 2. Insert System Users (Admins, Technicians, Households, Businesses)
PRINT 'Inserting Users...';
INSERT INTO Users (Username, Email, PasswordHash, PasswordSalt, UserType, FirstName, LastName, PhoneNumber, AddressLine1, City, PostalCode, RegionID, MeterNumber, AccountNumber, IsVerified)
VALUES 
    -- Admin Users
    ('eskom_admin', 'admin@eskom.co.za', 'hashed_password_1', 'salt_1', 'Admin', 'Thabo', 'Mbeki', '+27111234567', 'Megawatt Park, 1 Maxwell Drive', 'Johannesburg', '2054', 1, 'ADM001', 'ACC-ADM001', 1),
    ('ctpower_admin', 'admin@ctpower.co.za', 'hashed_password_2', 'salt_2', 'Admin', 'Nadia', 'Peterson', '+27219876543', 'Civic Centre, 12 Hertzog Blvd', 'Cape Town', '8001', 2, 'ADM002', 'ACC-ADM002', 1),
    
    -- Technicians
    ('tech_john', 'john.tech@eskom.co.za', 'hashed_password_3', 'salt_3', 'Technician', 'John', 'Khumalo', '+27112345678', '152 Main Road', 'Johannesburg', '2001', 1, 'TEC001', 'ACC-TEC001', 1),
    ('tech_sarah', 'sarah.m@ctpower.co.za', 'hashed_password_4', 'salt_4', 'Technician', 'Sarah', 'Mohammed', '+27223456789', '45 Long Street', 'Cape Town', '8000', 2, 'TEC002', 'ACC-TEC002', 1),
    
    -- Household Users
    ('house_smith', 'smith.family@email.com', 'hashed_password_5', 'salt_5', 'Household', 'David', 'Smith', '+27113456789', '25 Oak Avenue, Houghton', 'Johannesburg', '2198', 1, 'MTR0001', 'ACC-HH001', 1),
    ('house_jones', 'jones.ct@email.com', 'hashed_password_6', 'salt_6', 'Household', 'Amanda', 'Jones', '+27224567890', '8 Kloof Road, Gardens', 'Cape Town', '8001', 2, 'MTR0002', 'ACC-HH002', 1),
    ('house_ndlovu', 's.ndlovu@email.com', 'hashed_password_7', 'salt_7', 'Household', 'Sipho', 'Ndlovu', '+27114567891', '127 Vilakazi Street', 'Soweto', '1804', 5, 'MTR0003', 'ACC-HH003', 1),
    
    -- Business Users
    ('biz_shoprite', 'energy@shoprite.co.za', 'hashed_password_8', 'salt_8', 'Business', 'Shoprite', 'Group', '+27115678912', 'Cnr William Nicol & Republic Road', 'Johannesburg', '2191', 1, 'MTR0004', 'ACC-BIZ001', 1),
    ('biz_woolworths', 'facilities@woolworths.co.za', 'hashed_password_9', 'salt_9', 'Business', 'Woolworths', 'Stores', '+27226789012', '90 Rivonia Road', 'Sandton', '2196', 1, 'MTR0005', 'ACC-BIZ002', 1);

-- 3. Insert User Profiles
PRINT 'Inserting User Profiles...';
INSERT INTO UserProfiles (UserID, DateOfBirth, IDNumber, Occupation, HouseholdSize, PropertyType, PropertySizeSqM, AverageMonthlyIncome, EnergyConsumptionAwareness, HasElectricVehicle, HasSolarPanels, HasGenerator, HasBatteryBackup)
VALUES
    (5, '1980-03-15', '8003155123089', 'Engineer', 4, 'House', 350, 85000, 'High', 1, 1, 0, 1),
    (6, '1975-08-22', '7508224123087', 'Architect', 3, 'House', 280, 75000, 'High', 0, 1, 1, 0),
    (7, '1988-12-05', '8812050123085', 'Teacher', 5, 'House', 180, 45000, 'Medium', 0, 0, 0, 0),
    (8, NULL, 'COMP001', 'Retail Chain', 50, 'Business', 5000, 5000000, 'High', 0, 1, 1, 1),
    (9, NULL, 'COMP002', 'Retail Chain', 35, 'Business', 3500, 3500000, 'High', 0, 0, 1, 1);

-- 4. Insert Load Shedding Schedules
PRINT 'Inserting Load Shedding Schedules...';
INSERT INTO Schedules (RegionID, Stage, StartTime, EndTime, DayOfWeek, IsRecurring, ScheduleType, CreatedBy, EffectiveFrom, EffectiveTo)
VALUES
    -- Johannesburg Schedules
    (1, 2, '08:00', '10:30', 1, 1, 'Normal', 1, '2024-01-01', '2024-12-31'),
    (1, 2, '12:00', '14:30', 1, 1, 'Normal', 1, '2024-01-01', '2024-12-31'),
    (1, 3, '06:00', '08:30', 2, 1, 'Normal', 1, '2024-01-01', '2024-12-31'),
    (1, 3, '16:00', '18:30', 2, 1, 'Normal', 1, '2024-01-01', '2024-12-31'),
    
    -- Cape Town Schedules
    (2, 2, '09:00', '11:30', 1, 1, 'Normal', 2, '2024-01-01', '2024-12-31'),
    (2, 2, '17:00', '19:30', 3, 1, 'Normal', 2, '2024-01-01', '2024-12-31'),
    (2, 4, '05:00', '07:30', 4, 1, 'Normal', 2, '2024-01-01', '2024-12-31'),
    
    -- Durban Schedules
    (3, 2, '10:00', '12:30', 5, 1, 'Normal', 1, '2024-01-01', '2024-12-31'),
    (3, 3, '14:00', '16:30', 5, 1, 'Normal', 1, '2024-01-01', '2024-12-31'),
    
    -- Soweto Schedules
    (5, 2, '08:00', '10:30', 2, 1, 'Normal', 1, '2024-01-01', '2024-12-31'),
    (5, 2, '18:00', '20:30', 4, 1, 'Normal', 1, '2024-01-01', '2024-12-31');

-- 5. Insert Power Usage Data (Realistic South African consumption patterns)
PRINT 'Inserting Power Usage Data...';
INSERT INTO PowerUsage (UserID, MeterReading, UsageKWH, Timestamp, Temperature, Humidity, IsPeakHours, IsLoadShedding, CostPerKWH, TotalCost, Voltage, CurrentReading)
VALUES
    -- Household 1 - Normal usage patterns
    (5, 1500.25, 2.45, '2024-01-15 06:00:00', 18.5, 65, 0, 0, 2.55, 6.25, 230, 10.5),
    (5, 1502.70, 2.35, '2024-01-15 07:00:00', 19.0, 62, 1, 0, 2.55, 5.99, 229, 10.2),
    (5, 1508.90, 6.20, '2024-01-15 18:00:00', 25.5, 55, 1, 1, 2.55, 15.81, 0, 0),
    (5, 1512.15, 3.25, '2024-01-15 19:00:00', 24.0, 58, 1, 1, 2.55, 8.29, 0, 0),
    
    -- Household 2 - Cape Town usage
    (6, 890.75, 1.85, '2024-01-15 07:00:00', 16.5, 72, 0, 0, 2.35, 4.35, 230, 8.0),
    (6, 895.20, 4.45, '2024-01-15 17:00:00', 22.0, 65, 1, 0, 2.35, 10.46, 228, 19.5),
    (6, 898.65, 3.45, '2024-01-15 18:00:00', 21.5, 68, 1, 1, 2.35, 8.11, 0, 0),
    
    -- Business 1 - High consumption
    (8, 12500.50, 45.75, '2024-01-15 08:00:00', 22.0, 50, 0, 0, 1.85, 84.64, 400, 65.2),
    (8, 12585.25, 84.75, '2024-01-15 12:00:00', 23.5, 48, 0, 0, 1.85, 156.79, 400, 120.8),
    (8, 12620.80, 35.55, '2024-01-15 18:00:00', 21.0, 52, 1, 1, 1.85, 65.77, 0, 0);

-- 6. Insert Outages (Real South African outage scenarios)
PRINT 'Inserting Outages...';
INSERT INTO Outages (RegionID, OutageType, StartTime, EndTime, EstimatedRestoration, Stage, AffectedCustomers, Description, Cause, Status, Priority, ReportedBy, ConfirmedBy)
VALUES
    (1, 'LoadShedding', '2024-01-15 08:00:00', '2024-01-15 10:30:00', '2024-01-15 10:30:00', 2, 25000, 'Stage 2 Load Shedding - Johannesburg Central', 'Eskom Generation Capacity Shortage', 'Resolved', 'Medium', 3, 1),
    (2, 'LoadShedding', '2024-01-15 09:00:00', '2024-01-15 11:30:00', '2024-01-15 11:30:00', 2, 18000, 'Stage 2 Load Shedding - Cape Town Southern', 'National Grid Constraints', 'Resolved', 'Medium', 4, 2),
    (1, 'Fault', '2024-01-14 14:25:00', '2024-01-14 17:45:00', '2024-01-14 17:30:00', NULL, 1500, 'Transformer fault on Main Substation', 'Transformer Overload - Equipment Failure', 'Resolved', 'High', 5, 3),
    (5, 'Maintenance', '2024-01-16 09:00:00', NULL, '2024-01-16 15:00:00', NULL, 8000, 'Planned maintenance - Soweto Power Line Upgrade', 'Scheduled Infrastructure Upgrade', 'Active', 'Medium', 3, 1),
    (3, 'Weather', '2024-01-13 16:20:00', '2024-01-13 20:15:00', '2024-01-13 19:45:00', NULL, 12000, 'Storm damage to power lines', 'Severe Thunderstorm - Fallen Trees on Lines', 'Resolved', 'High', 4, 1);

-- 7. Insert Outage Updates
PRINT 'Inserting Outage Updates...';
INSERT INTO OutageUpdates (OutageID, UpdateType, Title, Description, UpdatedBy)
VALUES
    (4, 'ProgressUpdate', 'Maintenance Started', 'Crews have arrived on site and begun the scheduled maintenance work.', 3),
    (4, 'ETAUpdate', 'Update on Restoration Time', 'Work is progressing well. Estimated restoration time remains 15:00.', 3),
    (3, 'CauseIdentified', 'Fault Identified', 'Transformer overload caused by illegal connections in the area.', 3),
    (3, 'Resolution', 'Power Restored', 'Temporary transformer installed and power restored to all affected customers.', 3);

-- 8. Insert Backup Systems
PRINT 'Inserting Backup Systems...';
INSERT INTO BackupSystems (UserID, BackupType, SystemCapacityKWH, SystemCapacityKW, Manufacturer, Model, InstallationDate, WarrantyExpiry, FuelType, BatteryCapacityAH, SolarPanelCount, SolarPanelWattage)
VALUES
    (5, 'Hybrid', 10.5, 5.0, 'Sunsynk', '5kW Hybrid Inverter', '2023-03-15', '2028-03-15', 'None', 200, 8, 455),
    (6, 'Generator', 25.0, 8.5, 'Yamaha', 'EG8000', '2022-11-20', '2024-11-20', 'Petrol', NULL, NULL, NULL),
    (8, 'Solar', 50.0, 15.0, 'Canadian Solar', 'Commercial System', '2023-06-10', '2033-06-10', 'None', 400, 32, 470),
    (9, 'Battery', 20.0, 10.0, 'Tesla', 'Powerwall 2', '2023-08-05', '2033-08-05', 'Electric', 250, NULL, NULL);

-- 9. Insert Backup Usage
PRINT 'Inserting Backup Usage...';
INSERT INTO BackupUsage (BackupID, PowerGeneratedKWH, PowerUsedKWH, PowerStoredKWH, BatteryLevelPercent, GeneratorRunningHours, FuelLevelPercent, Timestamp, AmbientTemperature, SystemEfficiency)
VALUES
    (1, 3.2, 2.8, 0.4, 85.5, NULL, NULL, '2024-01-15 08:00:00', 25.0, 92.5),
    (1, 4.5, 3.1, 1.4, 92.0, NULL, NULL, '2024-01-15 12:00:00', 28.5, 94.2),
    (2, 0, 8.5, 0, NULL, 2.5, 75.0, '2024-01-15 09:00:00', 22.0, 88.0),
    (3, 12.8, 10.2, 2.6, 78.5, NULL, NULL, '2024-01-15 10:00:00', 26.0, 95.1);

-- 10. Insert Tariffs (South African electricity tariffs 2024)
PRINT 'Inserting Tariffs...';
INSERT INTO Tariffs (TariffName, TariffCode, RegionID, CustomerType, BaseRate, PeakRate, OffPeakRate, WeekendRate, PeakHoursStart, PeakHoursEnd, EffectiveFrom)
VALUES
    ('Residential Standard', 'RES-STD-001', 1, 'Residential', 2.55, 3.85, 1.25, 1.85, '18:00', '20:00', '2024-01-01'),
    ('Business Standard', 'BIZ-STD-001', 1, 'Business', 1.85, 2.95, 0.95, 1.45, '18:00', '20:00', '2024-01-01'),
    ('CT Residential', 'CT-RES-001', 2, 'Residential', 2.35, 3.55, 1.15, 1.65, '17:00', '19:00', '2024-01-01'),
    ('Industrial Large', 'IND-LRG-001', 1, 'Industrial', 1.45, 2.25, 0.75, 1.15, '18:00', '20:00', '2024-01-01');

-- 11. Insert Billing Information
PRINT 'Inserting Billing Information...';
INSERT INTO Billing (UserID, BillingMonth, TotalUsageKWH, TotalAmount, VATAmount, DueDate, PaymentStatus, InvoiceNumber)
VALUES
    (5, '2023-12-01', 345.75, 881.66, 115.00, '2024-01-25', 'Paid', 'INV-202312-HH001'),
    (6, '2023-12-01', 285.50, 670.93, 87.50, '2024-01-25', 'Paid', 'INV-202312-HH002'),
    (8, '2023-12-01', 12580.25, 23273.46, 3035.67, '2024-01-25', 'Pending', 'INV-202312-BIZ001'),
    (9, '2023-12-01', 8560.75, 15837.39, 2065.75, '2024-01-25', 'Pending', 'INV-202312-BIZ002');

-- 12. Insert Billing Details
PRINT 'Inserting Billing Details...';
INSERT INTO BillingDetails (BillID, Description, Quantity, UnitPrice, Amount, TaxRate, TaxAmount)
VALUES
    (1, 'Energy Consumption - Standard Rate', 300.25, 2.55, 765.64, 0.15, 114.85),
    (1, 'Network Charges', 1, 45.00, 45.00, 0.15, 6.75),
    (1, 'Service Fee', 1, 15.00, 15.00, 0.15, 2.25),
    (2, 'Energy Consumption - Standard Rate', 250.75, 2.35, 589.26, 0.15, 88.39),
    (2, 'Network Charges', 1, 35.00, 35.00, 0.15, 5.25);

-- 13. Insert Alerts
PRINT 'Inserting Alerts...';
INSERT INTO Alerts (UserID, AlertType, Title, Message, IsRead, Priority, RelatedOutageID, RelatedScheduleID, ExpiryDate)
VALUES
    (5, 'LoadSheddingStart', 'Load Shedding Starting Soon', 'Load shedding for your area starts at 08:00 and ends at 10:30. Stage 2.', 0, 'Medium', 1, 1, '2024-01-15 10:30:00'),
    (6, 'LoadSheddingStart', 'Load Shedding Notification', 'Load shedding scheduled from 09:00 to 11:30. Stage 2. Prepare your backup systems.', 1, 'Medium', 2, 5, '2024-01-15 11:30:00'),
    (5, 'HighUsage', 'High Energy Usage Alert', 'Your energy usage is 25% higher than your average. Consider reducing consumption during peak hours.', 0, 'Low', NULL, NULL, '2024-01-20 23:59:59'),
    (8, 'OutageReported', 'Power Outage in Your Area', 'Unplanned outage reported in your area. Crew dispatched. Estimated restoration: 15:00', 0, 'High', 4, NULL, '2024-01-16 15:00:00');

-- 14. Insert Alert Preferences
PRINT 'Inserting Alert Preferences...';
INSERT INTO AlertPreferences (UserID, AlertType, Channel, IsEnabled, MinimumPriority, QuietHoursStart, QuietHoursEnd)
VALUES
    (5, 'LoadSheddingStart', 'Both', 1, 'Low', '22:00', '06:00'),
    (5, 'LoadSheddingEnd', 'SMS', 1, 'Low', '22:00', '06:00'),
    (5, 'HighUsage', 'Email', 1, 'Medium', '22:00', '06:00'),
    (6, 'LoadSheddingStart', 'Push', 1, 'Medium', '23:00', '07:00'),
    (8, 'OutageReported', 'Both', 1, 'High', '00:00', '05:00');

-- 15. Insert Energy Goals
PRINT 'Inserting Energy Goals...';
INSERT INTO EnergyGoals (UserID, GoalType, TargetKWH, TargetCost, StartDate, EndDate, CurrentProgressKWH, CurrentProgressCost)
VALUES
    (5, 'Monthly', 320.00, 800.00, '2024-01-01', '2024-01-31', 185.25, 472.39),
    (6, 'Monthly', 270.00, 600.00, '2024-01-01', '2024-01-31', 152.75, 358.96),
    (8, 'Monthly', 12000.00, 22000.00, '2024-01-01', '2024-01-31', 6850.50, 12673.43);

-- 16. Insert System Settings
PRINT 'Inserting System Settings...';
INSERT INTO SystemSettings (SettingKey, SettingValue, SettingType, Description, IsActive)
VALUES
    ('SystemName', 'Load Shedding & Energy Monitoring System', 'String', 'Application display name', 1),
    ('DefaultCountry', 'South Africa', 'String', 'Default country for the system', 1),
    ('Currency', 'ZAR', 'String', 'Default currency', 1),
    ('VATRate', '0.15', 'Number', 'Value Added Tax rate', 1),
    ('PeakHoursStart', '18:00', 'String', 'Default peak hours start time', 1),
    ('PeakHoursEnd', '20:00', 'String', 'Default peak hours end time', 1),
    ('MaxLoadSheddingStage', '8', 'Number', 'Maximum load shedding stage supported', 1),
    ('DataRetentionMonths', '36', 'Number', 'Number of months to keep historical data', 1),
    ('AlertBatchSize', '1000', 'Number', 'Number of alerts to process in one batch', 1),
    ('MaintenanceReminderDays', '30', 'Number', 'Days before maintenance to send reminder', 1);

-- 17. Insert Maintenance Logs
PRINT 'Inserting Maintenance Logs...';
INSERT INTO MaintenanceLogs (BackupID, MaintenanceType, Description, PerformedBy, PerformedDate, NextMaintenanceDate, Cost, PartsReplaced, WorkHours, TechnicianNotes)
VALUES
    (1, 'Routine', 'Quarterly system inspection and cleaning', 'SolarTech SA', '2023-12-15', '2024-03-15', 850.00, 'None', 2.5, 'System performing optimally. Battery health at 98%'),
    (2, 'Repair', 'Spark plug replacement and oil change', 'Generator Services CT', '2024-01-10', '2024-04-10', 1200.00, 'Spark Plugs, Oil Filter, Engine Oil', 1.5, 'Generator running smoothly after service');

-- 18. Insert Notifications Log
PRINT 'Inserting Notifications Log...';
INSERT INTO NotificationsLog (UserID, NotificationType, Channel, Subject, Message, Status, SentDate, DeliveredDate)
VALUES
    (5, 'LoadSheddingStart', 'SMS', 'Load Shedding Alert', 'Load shedding starts at 08:00. Stage 2.', 'Delivered', '2024-01-15 07:00:00', '2024-01-15 07:00:05'),
    (5, 'LoadSheddingStart', 'Email', 'Load Shedding Starting Soon', 'Load shedding for your area starts at 08:00...', 'Sent', '2024-01-15 07:00:00', NULL),
    (6, 'LoadSheddingStart', 'Push', 'Load Shedding Notification', 'Load shedding scheduled from 09:00 to 11:30', 'Delivered', '2024-01-15 08:00:00', '2024-01-15 08:00:01');

PRINT 'Sample data insertion completed successfully!';
PRINT 'Summary of inserted records:';
PRINT '- Regions: ' + CAST((SELECT COUNT(*) FROM Regions) AS NVARCHAR(10));
PRINT '- Users: ' + CAST((SELECT COUNT(*) FROM Users) AS NVARCHAR(10));
PRINT '- Schedules: ' + CAST((SELECT COUNT(*) FROM Schedules) AS NVARCHAR(10));
PRINT '- Power Usage: ' + CAST((SELECT COUNT(*) FROM PowerUsage) AS NVARCHAR(10));
PRINT '- Outages: ' + CAST((SELECT COUNT(*) FROM Outages) AS NVARCHAR(10));
PRINT '- Backup Systems: ' + CAST((SELECT COUNT(*) FROM BackupSystems) AS NVARCHAR(10));
PRINT '- Alerts: ' + CAST((SELECT COUNT(*) FROM Alerts) AS NVARCHAR(10));
PRINT '- Billing Records: ' + CAST((SELECT COUNT(*) FROM Billing) AS NVARCHAR(10));

-- Display some sample data for verification
PRINT '';
PRINT 'Sample Data Verification:';
PRINT 'Top 5 Load Shedding Schedules:';
SELECT TOP 5 
    r.RegionName, 
    s.Stage, 
    s.StartTime, 
    s.EndTime,
    CASE s.DayOfWeek 
        WHEN 1 THEN 'Sunday'
        WHEN 2 THEN 'Monday' 
        WHEN 3 THEN 'Tuesday'
        WHEN 4 THEN 'Wednesday'
        WHEN 5 THEN 'Thursday'
        WHEN 6 THEN 'Friday'
        WHEN 7 THEN 'Saturday'
    END as DayOfWeek
FROM Schedules s
JOIN Regions r ON s.RegionID = r.RegionID
ORDER BY r.RegionName, s.DayOfWeek, s.StartTime;

PRINT '';
PRINT 'Current Active Outages:';
SELECT 
    r.RegionName,
    o.OutageType,
    o.StartTime,
    o.EstimatedRestoration,
    o.AffectedCustomers,
    o.Status
FROM Outages o
JOIN Regions r ON o.RegionID = r.RegionID
WHERE o.Status = 'Active';