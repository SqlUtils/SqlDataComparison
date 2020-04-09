/*
 * TEST DATABASE A
 */

USE SqlUtilsTests_A
GO

IF (object_id('AddressTypes', 'U') IS NOT NULL)
  DROP TABLE AddressTypes
GO

CREATE TABLE AddressTypes (
    AddressTypeID INT IDENTITY(1, 1),
    AddressType NVARCHAR(50),
    CONSTRAINT PK_AddressTypes PRIMARY KEY CLUSTERED (
        AddressTypeID ASC
    )
)
GO

INSERT INTO AddressTypes ( AddressType )
VALUES ('Home')
GO

IF (object_id('CountryTable', 'U') IS NOT NULL)
  DROP TABLE CountryTable
GO

CREATE TABLE [dbo].[CountryTable](
    [CountryID] [int] NOT NULL,
    [Country] [varchar](50) NOT NULL,
    [Abbreviation] [varchar](10) NULL,
    [CountryRegionID] [int] NOT NULL,
    [Valid] [bit] NOT NULL,
    CONSTRAINT [PK_CountryTable] PRIMARY KEY CLUSTERED 
    (
        [CountryID] ASC
    )
)
GO

INSERT INTO CountryTable (CountryID, Country, Abbreviation, CountryRegionID, Valid)
VALUES
  (1, 'Åland Islands', NULL, 9, 0),
  (19, 'Barbados', NULL, 6, 1),
  (158, 'Niue', NULL, 12, 0),
  (159, 'Norfolk Island', NULL, 12, 0),
  (230, 'United Kingdom', 'UK', 8, 1),
  (231, 'United States', 'US', 11, 1),
  (244, 'Zambia', NULL, 1, 1)
GO

/*
 * TEST DATABASE B
 */

USE SqlUtilsTests_B
GO

IF (object_id('AddressTypes', 'U') IS NOT NULL)
  DROP TABLE AddressTypes
GO

CREATE TABLE AddressTypes (
    AddressTypeID INT IDENTITY(1, 1),
    AddressType NVARCHAR(50),
    CONSTRAINT PK_AddressTypes PRIMARY KEY CLUSTERED (
        AddressTypeID ASC
    )
)
GO

INSERT INTO AddressTypes ( AddressType )
VALUES ('Home'), ('Term'), ('Work')
GO

/*
 * TEST DATABASE C
 */

USE SqlUtilsTests_C
GO

IF (object_id('AddressMatch', 'U') IS NOT NULL)
  DROP TABLE AddressMatch
GO

CREATE TABLE AddressMatch (
    ID INT,
    [Type] NVARCHAR(50)
)
GO

INSERT INTO AddressMatch ( ID, [Type] )
VALUES (1, 'Home'), (2, 'Term'), (3, 'Work'), (4, 'Other')
GO

IF (object_id('AddressTypes', 'U') IS NOT NULL)
  DROP TABLE AddressTypes
GO

CREATE TABLE AddressTypes (
    AddressTypeID INT IDENTITY(1, 1),
    AddressType NVARCHAR(50)
)
GO

INSERT INTO AddressTypes ( AddressType )
VALUES ('Home'), ('Term'), ('Work')
GO

IF (object_id('CountryList', 'U') IS NOT NULL)
  DROP TABLE CountryList
GO

CREATE TABLE [dbo].[CountryList](
    [CountryID] [int] NOT NULL,
    [Country] [nvarchar](50) NOT NULL,
    CONSTRAINT [PK_CountryList] PRIMARY KEY CLUSTERED 
    (
        [CountryID] ASC
    )
)
GO

INSERT INTO CountryList (CountryID, Country)
VALUES
  (19, 'Barbados'),
  (230, 'United Kingdom'),
  (231, 'United States'),
  (244, 'Zambia')
GO
