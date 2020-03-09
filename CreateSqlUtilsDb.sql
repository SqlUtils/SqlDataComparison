USE master
GO

IF EXISTS(select * from sys.databases where name='SqlUtils')
BEGIN
    ALTER DATABASE SqlUtils SET SINGLE_USER WITH ROLLBACK IMMEDIATE
    DROP DATABASE SqlUtils
END
GO

CREATE DATABASE SqlUtils
GO

USE SqlUtils
GO

CREATE SCHEMA internals
GO
