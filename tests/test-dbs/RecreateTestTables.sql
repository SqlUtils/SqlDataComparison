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
