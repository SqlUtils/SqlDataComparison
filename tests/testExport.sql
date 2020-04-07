USE SqlUtils
GO

EXEC tSQLt.NewTestClass 'testExport';
GO

CREATE PROCEDURE testExport.[test exporting added rows a->b does nothing]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	SELECT *
	INTO #OriginalValues
	FROM SqlUtilsTests_A..AddressTypes

	EXEC tSQLt.CaptureOutput 'EXEC ExportAddedRows ''SqlUtilsTests_A..AddressTypes'', ''SqlUtilsTests_B..AddressTypes'''

	SELECT CAST (
		@CRLF +
		'Exporting added rows...' + @CRLF +
		'Requested export completed with no errors. Transferred 0 rows from [ours] into [theirs].' + @CRLF
		AS NVARCHAR(MAX)) AS OutputText
	INTO #TestOutput

	EXEC tSQLt.AssertEqualsTable '#TestOutput', 'SqlUtils.tSQLt.CaptureOutputLog'

	EXEC tSQLt.AssertEqualsTable '#OriginalValues', 'SqlUtilsTests_A..AddressTypes'
END
GO

CREATE PROCEDURE testExport.[test exporting changed rows a->b does nothing]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	SELECT *
	INTO #OriginalValues
	FROM SqlUtilsTests_A..AddressTypes

	EXEC tSQLt.CaptureOutput 'EXEC ExportChangedRows ''SqlUtilsTests_A..AddressTypes'', ''SqlUtilsTests_B..AddressTypes'''

	SELECT CAST (
		@CRLF +
		'Exporting changed rows...' + @CRLF +
		'Requested export completed with no errors. Updated 0 rows in [theirs] with data from [ours].' + @CRLF
		AS NVARCHAR(MAX)) AS OutputText
	INTO #TestOutput

	EXEC tSQLt.AssertEqualsTable '#TestOutput', 'SqlUtils.tSQLt.CaptureOutputLog'

	EXEC tSQLt.AssertEqualsTable '#OriginalValues', 'SqlUtilsTests_A..AddressTypes'
END
GO

CREATE PROCEDURE testExport.[test exporting deleted rows a->b deletes them]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	EXEC tSQLt.CaptureOutput 'EXEC ExportDeletedRows ''SqlUtilsTests_A..AddressTypes'', ''SqlUtilsTests_B..AddressTypes'''

	SELECT CAST (
		@CRLF +
		'Exporting deleted rows...' + @CRLF +
		'Requested export completed with no errors. Deleted 2 rows from [theirs].' + @CRLF +
		+ @CRLF +
		'No data differences found between OURS <<< [SqlUtilsTests_A].[dbo].[AddressTypes] and THEIRS >>> [SqlUtilsTests_B].[dbo].[AddressTypes].' + @CRLF
		AS NVARCHAR(MAX)) AS OutputText
	INTO #TestOutput

	EXEC tSQLt.AssertEqualsTable '#TestOutput', 'SqlUtils.tSQLt.CaptureOutputLog'

	EXEC tSQLt.AssertEqualsTable 'SqlUtilsTests_A..AddressTypes', 'SqlUtilsTests_B..AddressTypes'
END
GO
