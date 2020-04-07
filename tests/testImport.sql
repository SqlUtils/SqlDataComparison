USE SqlUtils
GO

EXEC tSQLt.NewTestClass 'testImport';
GO

CREATE PROCEDURE testImport.[test importing deleted rows b->a does nothing]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	SELECT *
	INTO #OriginalValues
	FROM SqlUtilsTests_A..AddressTypes

	EXEC tSQLt.CaptureOutput 'EXEC ImportDeletedRows ''SqlUtilsTests_A..AddressTypes'', ''SqlUtilsTests_B..AddressTypes'''

	SELECT CAST (
		@CRLF +
		'Importing deleted rows...' + @CRLF +
		'Requested import completed with no errors. Deleted 0 rows from [ours].' + @CRLF
		AS NVARCHAR(MAX)) AS OutputText
	INTO #TestOutput

	EXEC tSQLt.AssertEqualsTable '#TestOutput', 'SqlUtils.tSQLt.CaptureOutputLog'

	EXEC tSQLt.AssertEqualsTable '#OriginalValues', 'SqlUtilsTests_A..AddressTypes'
END
GO

CREATE PROCEDURE testImport.[test importing changed rows b->a does nothing]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	SELECT *
	INTO #OriginalValues
	FROM SqlUtilsTests_A..AddressTypes

	EXEC tSQLt.CaptureOutput 'EXEC ImportChangedRows ''SqlUtilsTests_A..AddressTypes'', ''SqlUtilsTests_B..AddressTypes'''

	SELECT CAST (
		@CRLF +
		'Importing changed rows...' + @CRLF +
		'Requested import completed with no errors. Updated 0 rows in [ours] with data from [theirs].' + @CRLF
		AS NVARCHAR(MAX)) AS OutputText
	INTO #TestOutput

	EXEC tSQLt.AssertEqualsTable '#TestOutput', 'SqlUtils.tSQLt.CaptureOutputLog'

	EXEC tSQLt.AssertEqualsTable '#OriginalValues', 'SqlUtilsTests_A..AddressTypes'
END
GO

CREATE PROCEDURE testImport.[test importing added rows b->a adds them]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	EXEC tSQLt.CaptureOutput 'EXEC ImportAddedRows ''SqlUtilsTests_A..AddressTypes'', ''SqlUtilsTests_B..AddressTypes'''

	SELECT CAST (
		@CRLF +
		'Importing added rows...' + @CRLF +
		'Requested import completed with no errors. Transferred 2 rows from [theirs] into [ours].' + @CRLF +
		+ @CRLF +
		'No data differences found between OURS <<< [SqlUtilsTests_A].[dbo].[AddressTypes] and THEIRS >>> [SqlUtilsTests_B].[dbo].[AddressTypes].' + @CRLF
		AS NVARCHAR(MAX)) AS OutputText
	INTO #TestOutput

	EXEC tSQLt.AssertEqualsTable '#TestOutput', 'SqlUtils.tSQLt.CaptureOutputLog'

	EXEC tSQLt.AssertEqualsTable 'SqlUtilsTests_B..AddressTypes', 'SqlUtilsTests_A..AddressTypes'
END
GO
