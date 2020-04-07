/*
 * TEST DATABASE A
 */

USE tempdb;
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

USE tempdb;
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

USE tempdb;
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