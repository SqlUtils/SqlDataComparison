/*
 * TEST DATABASE A
 */

USE master
GO

IF EXISTS(select * from sys.databases where name='SqlUtilsTests_A')
BEGIN
	ALTER DATABASE SqlUtilsTests_A SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE SqlUtilsTests_A
END
GO

CREATE DATABASE SqlUtilsTests_A
GO

USE SqlUtilsTests_A
GO

CREATE TABLE AddressTypes (
    AddressTypeID INT IDENTITY(1, 1),
    AddressType NVARCHAR(50),
    CONSTRAINT PK_AddressTypes PRIMARY KEY CLUSTERED (
        AddressTypeID ASC
    )
)

INSERT INTO AddressTypes ( AddressType )
VALUES ('Home')

GO

/*
 * TEST DATABASE B
 */

USE master
GO

IF EXISTS(select * from sys.databases where name='SqlUtilsTests_B')
BEGIN
	ALTER DATABASE SqlUtilsTests_B SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE SqlUtilsTests_B
END
GO

CREATE DATABASE SqlUtilsTests_B
GO

USE SqlUtilsTests_B
GO

CREATE TABLE AddressTypes (
    AddressTypeID INT IDENTITY(1, 1),
    AddressType NVARCHAR(50),
    CONSTRAINT PK_AddressTypes PRIMARY KEY CLUSTERED (
        AddressTypeID ASC
    )
)

INSERT INTO AddressTypes ( AddressType )
VALUES ('Home'), ('Term'), ('Work')

GO

/*
 * TEST DATABASE C
 */

USE master
GO

IF EXISTS(select * from sys.databases where name='SqlUtilsTests_C')
BEGIN
	ALTER DATABASE SqlUtilsTests_C SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE SqlUtilsTests_C
END
GO

CREATE DATABASE SqlUtilsTests_C
GO

USE SqlUtilsTests_C
GO

CREATE TABLE AddressMatch (
    ID INT,
    [Type] NVARCHAR(50)
)

INSERT INTO AddressMatch ( ID, [Type] )
VALUES (1, 'Home'), (2, 'Term'), (3, 'Work'), (4, 'Other')

GO