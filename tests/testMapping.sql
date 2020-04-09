USE SqlUtils
GO

EXEC tSQLt.NewTestClass 'testMapping';
GO

CREATE PROCEDURE testMapping.[test compare with map works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
		'Data differences found between OURS <<< [SqlUtilsTests_A].[dbo].[AddressTypes] and THEIRS >>> [SqlUtilsTests_C].[dbo].[AddressMatch].' + @CRLF +
		' - Switch to results window to view differences.' + @CRLF +
		' - Call [Import|Export][Added|Deleted|Changed|All] (e.g. ImportAdded) with the same arguments to transfer changes.' + @CRLF

	EXEC tSQLt.ExpectException @Message, 16, 1

	EXEC CompareData 'SqlUtilsTests_A..AddressTypes', 'SqlUtilsTests_C..AddressMatch', @map = 'AddressTypeID,ID;AddressType,Type'

END
GO

CREATE PROCEDURE testMapping.[test map warning no target column works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
		'Target column name ''xID'' specified in @map does not exist in [SqlUtilsTests_C].[dbo].[AddressMatch]'

	EXEC tSQLt.ExpectException @Message, 16, 1

	EXEC CompareData 'SqlUtilsTests_A..AddressTypes', 'SqlUtilsTests_C..AddressMatch', @map = 'AddressTypeID,xID;AddressType,Type'

END
GO

CREATE PROCEDURE testMapping.[test map warning no source column works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
		'Source column name ''xAddressType'' specified in @map does not exist in [SqlUtilsTests_A].[dbo].[AddressTypes]'

	EXEC tSQLt.ExpectException @Message, 16, 1

	EXEC CompareData 'SqlUtilsTests_A..AddressTypes', 'SqlUtilsTests_C..AddressMatch', @map = 'AddressTypeID,ID;xAddressType,Type'

END
GO
