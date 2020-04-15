USE SqlUtils
GO

EXEC tSQLt.NewTestClass 'testMapping';
GO

CREATE PROCEDURE testMapping.[test basic map works]
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

CREATE PROCEDURE testMapping.[test map plus ids param works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	-- make mismatches on both sides
	SET IDENTITY_INSERT SqlUtilsTests_A.dbo.AddressTypes ON;
	INSERT INTO SqlUtilsTests_A.dbo.AddressTypes (AddressTypeID, AddressType)
	VALUES (3, 'Work')
	SET IDENTITY_INSERT SqlUtilsTests_A.dbo.AddressTypes OFF;
	DELETE FROM SqlUtilsTests_C..AddressMatch WHERE ID = 3
	UPDATE SqlUtilsTests_A.dbo.AddressTypes SET AddressType = 'Test' WHERE AddressTypeID = 1

	EXEC tSQLt.CaptureOutput 'EXEC ImportAll ''SqlUtilsTests_A..AddressTypes'', ''SqlUtilsTests_C..AddressMatch'', @map = ''AddressTypeID,ID;AddressType,Type'', @ids = ''1-3'''
	SELECT CAST (
		@CRLF +
		'Importing added rows...' + @CRLF +
		'Requested import completed with no errors. Transferred 1 rows from [theirs] into [ours].' + @CRLF +
		'' + @CRLF +
		'Importing deleted rows...' + @CRLF +
		'Requested import completed with no errors. Deleted 1 rows from [ours].' + @CRLF +
		'' + @CRLF +
		'Importing changed rows...' + @CRLF +
		'Requested import completed with no errors. Updated 1 rows in [ours] with data from [theirs].' + @CRLF +
		'' + @CRLF +
		'No data differences found between OURS <<< [SqlUtilsTests_A].[dbo].[AddressTypes] and THEIRS >>> [SqlUtilsTests_C].[dbo].[AddressMatch].' + @CRLF
		AS NVARCHAR(MAX)) AS OutputText
	INTO #TestOutput

	EXEC tSQLt.AssertEqualsTable '#TestOutput', 'SqlUtils.tSQLt.CaptureOutputLog'
END
GO

CREATE PROCEDURE testMapping.[test empty map param is illegal]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	EXEC tSQLt.ExpectException 'Illegal @map parameter ''''; use ''our_col1, their_col1; our_col2, their_col2'' quoting column names using [...] if necessary', 16, 1

	EXEC CompareData 'SqlUtilsTests_A..AddressTypes', 'SqlUtilsTests_C..AddressMatch', @map = ''
END
GO

CREATE PROCEDURE testMapping.internalTestIllegalMapParam
	@map NVARCHAR(MAX)
AS
BEGIN
	DECLARE @message NVARCHAR(MAX) = 'Illegal @map parameter ''' + @map + '''; use ''our_col1, their_col1; our_col2, their_col2'' quoting column names using [...] if necessary'

	EXEC tSQLt.ExpectException @message, 16, 1

	EXEC CompareData 'SqlUtilsTests_A..AddressTypes', 'SqlUtilsTests_C..AddressMatch', @map = @map
END
GO

CREATE PROCEDURE testMapping.[test incomplete map param is illegal #1]
AS
BEGIN
	EXEC testMapping.internalTestIllegalMapParam 'a,'
END
GO

CREATE PROCEDURE testMapping.[test incomplete map param is illegal #2]
AS
BEGIN
	EXEC testMapping.internalTestIllegalMapParam 'a,a;'
END
GO

CREATE PROCEDURE testMapping.[test incomplete map param is illegal #3]
AS
BEGIN
	EXEC testMapping.internalTestIllegalMapParam 'a,a;b'
END
GO

CREATE PROCEDURE testMapping.[test map warning no target column works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
		'Target column name ''[xID]'' specified in @map does not exist in [SqlUtilsTests_C].[dbo].[AddressMatch]'

	EXEC tSQLt.ExpectException @Message, 16, 1

	EXEC CompareData 'SqlUtilsTests_A..AddressTypes', 'SqlUtilsTests_C..AddressMatch', @map = 'AddressTypeID,xID;AddressType,Type'

END
GO

CREATE PROCEDURE testMapping.[test map warning no source column works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
		'Source column name ''[xAddressType]'' specified in @map does not exist in [SqlUtilsTests_A].[dbo].[AddressTypes]'

	EXEC tSQLt.ExpectException @Message, 16, 1

	EXEC CompareData 'SqlUtilsTests_A..AddressTypes', 'SqlUtilsTests_C..AddressMatch', @map = 'AddressTypeID,ID;xAddressType,Type'

END
GO
