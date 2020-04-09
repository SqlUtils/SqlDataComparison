USE SqlUtils
GO

EXEC tSQLt.NewTestClass 'testJoin';
GO

CREATE PROCEDURE testJoin.[test required join warning works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
		'There are no primary keys for table [SqlUtilsTests_C].[dbo].[AddressMatch]. One or more primary keys or a @join parameter are required to join the tables to be compared.'

	EXEC tSQLt.ExpectException @Message, 16, 1

	EXEC CompareData 'SqlUtilsTests_C..AddressMatch', 'SqlUtilsTests_A..AddressTypes', @map = 'ID,AddressTypeID;Type,AddressType'

END
GO

CREATE PROCEDURE testJoin.[test mapped join works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
	'Data differences found between OURS <<< [SqlUtilsTests_C].[dbo].[AddressMatch] and THEIRS >>> [SqlUtilsTests_A].[dbo].[AddressTypes].' + @CRLF +
	' - Switch to results window to view differences.' + @CRLF +
	' - Call [Import|Export][Added|Deleted|Changed|All] (e.g. ImportAdded) with the same arguments to transfer changes.' + @CRLF

	EXEC tSQLt.ExpectException @Message, 16, 1

	EXEC CompareData 'SqlUtilsTests_C..AddressMatch', 'SqlUtilsTests_A..AddressTypes', @map = 'ID,AddressTypeID;Type,AddressType', @join = 'ID'

END
GO

CREATE PROCEDURE testJoin.[test basic join works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
		'Data differences found between OURS <<< [SqlUtilsTests_C].[dbo].[AddressTypes] and THEIRS >>> [SqlUtilsTests_A].[dbo].[AddressTypes].' + @CRLF +
		' - Switch to results window to view differences.' + @CRLF +
		' - Call [Import|Export][Added|Deleted|Changed|All] (e.g. ImportAdded) with the same arguments to transfer changes.' + @CRLF

	EXEC tSQLt.ExpectException @Message, 16, 1

	EXEC CompareData 'SqlUtilsTests_C..AddressTypes', 'SqlUtilsTests_A..AddressTypes', @join = 'AddressTypeID'

END
GO

CREATE PROCEDURE testJoin.[test join invalid column warning works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
		'Column name ''xAddressTypeID'' specified in @join does not exist in [SqlUtilsTests_C].[dbo].[AddressTypes]'

	EXEC tSQLt.ExpectException @Message, 16, 1

	EXEC CompareData 'SqlUtilsTests_C..AddressTypes', 'SqlUtilsTests_A..AddressTypes', @join = 'xAddressTypeID'

END
GO
