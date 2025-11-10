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
