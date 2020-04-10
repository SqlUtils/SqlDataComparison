USE SqlUtils
GO

EXEC tSQLt.NewTestClass 'testUseWhereJoinIds';
GO

CREATE PROCEDURE testUseWhereJoinIds.[test @use works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
		'Data differences found between OURS <<< [SqlUtilsTests_A].[dbo].[CountryTable] and THEIRS >>> [SqlUtilsTests_C].[dbo].[CountryList].' + @CRLF +
		' - Switch to results window to view differences.' + @CRLF +
		' - Call [Import|Export][Added|Deleted|Changed|All] (e.g. ImportAdded) with the same arguments to transfer changes.' + @CRLF
	EXEC tSQLt.ExpectException @Message, 16, 1

	EXEC CompareData 'SqlUtilsTests_A..CountryTable', 'SqlUtilsTests_C..CountryList', @use='countryid, country'
END
GO

CREATE PROCEDURE testUseWhereJoinIds.[test @use + @where works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	EXEC tSQLt.CaptureOutput 'EXEC CompareData ''SqlUtilsTests_A..CountryTable'', ''SqlUtilsTests_C..CountryList'', @use=''countryid, country'', @where = ''[ours].valid = 1'''
	SELECT CAST (
		@CRLF +
		'No data differences found between OURS <<< [SqlUtilsTests_A].[dbo].[CountryTable] and THEIRS >>> [SqlUtilsTests_C].[dbo].[CountryList].' + @CRLF
		AS NVARCHAR(MAX)) AS OutputText
	INTO #TestOutput

	EXEC tSQLt.AssertEqualsTable '#TestOutput', 'SqlUtils.tSQLt.CaptureOutputLog'
END
GO

CREATE PROCEDURE testUseWhereJoinIds.[test @use + ImportDeleted works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	EXEC tSQLt.CaptureOutput 'EXEC ImportDeleted ''SqlUtilsTests_A..CountryTable'', ''SqlUtilsTests_C..CountryList'', @use=''countryid, country'''
	SELECT CAST (
		'' + @CRLF +
		'Importing deleted rows...' + @CRLF +
		'Requested import completed with no errors. Deleted 3 rows from [ours].' + @CRLF +
		'' + @CRLF +
		'No data differences found between OURS <<< [SqlUtilsTests_A].[dbo].[CountryTable] and THEIRS >>> [SqlUtilsTests_C].[dbo].[CountryList].' + @CRLF
		AS NVARCHAR(MAX)) AS OutputText
	INTO #TestOutput

	EXEC tSQLt.AssertEqualsTable '#TestOutput', 'SqlUtils.tSQLt.CaptureOutputLog'
END
GO

CREATE PROCEDURE testUseWhereJoinIds.[test @use + @ids + ImportDeleted works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	EXEC tSQLt.CaptureOutput 'EXEC ImportDeleted ''SqlUtilsTests_A..CountryTable'', ''SqlUtilsTests_C..CountryList'', @use=''countryid, country'', @ids=''150-160'''
	SELECT CAST (
		'' + @CRLF +
		'Importing deleted rows...' + @CRLF +
		'Requested import completed with no errors. Deleted 2 rows from [ours].' + @CRLF +
		'' + @CRLF +
		'No data differences found between OURS <<< [SqlUtilsTests_A].[dbo].[CountryTable] and THEIRS >>> [SqlUtilsTests_C].[dbo].[CountryList].' + @CRLF
		AS NVARCHAR(MAX)) AS OutputText
	INTO #TestOutput

	EXEC tSQLt.AssertEqualsTable '#TestOutput', 'SqlUtils.tSQLt.CaptureOutputLog'
END
GO

CREATE PROCEDURE testUseWhereJoinIds.[test ImportChanged with all join columns works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	EXEC tSQLt.CaptureOutput 'EXEC ImportChanged ''SqlUtilsTests_A..CountryTable'', ''SqlUtilsTests_C..CountryList'', @use=''countryid, country'', @showSql = 1'
	EXEC tSQLt.CaptureOutput 'EXEC ImportChanged ''SqlUtilsTests_A..CountryTable'', ''SqlUtilsTests_C..CountryList'', @use=''countryid, country'', @join=''countryid, country'', @showSql = 1'

	-- two rows
	SELECT *
	FROM SqlUtils.tSQLt.CaptureOutputLog

	EXEC tSQLt.AssertEquals 2, @@ROWCOUNT

	-- both did no updates
	SELECT *
	FROM SqlUtils.tSQLt.CaptureOutputLog
	WHERE OutputText LIKE '%Updated 0 rows%'

	EXEC tSQLt.AssertEquals 2, @@ROWCOUNT

	-- second row has special SQL required for all join columns situation
	DECLARE @id INT

	SELECT @id = id
	FROM SqlUtils.tSQLt.CaptureOutputLog
	WHERE OutputText LIKE '%0 = 1%'

	EXEC tSQLt.AssertEquals 1, @@ROWCOUNT
	EXEC tSQLt.AssertEquals 2, @id

END
GO
