USE SqlUtils
GO

EXEC tSQLt.NewTestClass 'testCrazyTables';
GO

CREATE PROCEDURE testCrazyTables.[test crazy table and column names]
AS
BEGIN
	SET NOCOUNT ON;

  DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

  DECLARE @SQL NVARCHAR(MAX)

  DECLARE @longestName sysname
  DECLARE @longName sysname
  DECLARE @daftName1 sysname
  DECLARE @daftName2 sysname

  SELECT
    @longestName = LongestName,
    @longName = LongName,
    @daftName1 = DaftName1,
    @daftName2 = DaftName2
  FROM SqlUtilsTests_A..SillyNames
  
	-- we just don't need REPLACE() for @longestname as it doesn't have any single quotes
	SET @SQL =
		'EXEC ImportAll ''[SqlUtilsTests_A].' + QUOTENAME(@longestname) + '.' + QUOTENAME(@longestname) + ''', ''[SqlUtilsTests_C]..' + REPLACE(QUOTENAME(@longname), '''', '''''') + '''' + @CRLF +
		', @join = ''' +
		REPLACE(QUOTENAME(@longname), '''', '''''') + ', ' + REPLACE(QUOTENAME(@daftname1), '''', '''''') +
		'''' + @CRLF +
		', @map = ''' +
		REPLACE(QUOTENAME(@longname), '''', '''''') + ', ' + REPLACE(QUOTENAME(@daftname2), '''', '''''') +
		'; ' +
		REPLACE(QUOTENAME(@daftname1), '''', '''''') + ', ' + QUOTENAME(@longestname) +
		'; ' +
		REPLACE(QUOTENAME(@daftname2), '''', '''''') + ', ' + REPLACE(QUOTENAME(@daftname1), '''', '''''') +
		''''
	EXEC tSQLt.CaptureOutput @SQL

	SELECT CAST (
		@CRLF +
		'Importing added rows...' + @CRLF +
		'Requested import completed with no errors. Transferred 0 rows from [theirs] into [ours].' + @CRLF +
		'' + @CRLF +
		'Importing deleted rows...' + @CRLF +
		'Requested import completed with no errors. Deleted 0 rows from [ours].' + @CRLF +
		'' + @CRLF +
		'Importing changed rows...' + @CRLF +
		'Requested import completed with no errors. Updated 1 rows in [ours] with data from [theirs].' + @CRLF +
		'' + @CRLF +
		'No data differences found between OURS <<< [SqlUtilsTests_A].[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]].[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]] and THEIRS >>> [SqlUtilsTests_C].[dbo].[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]''].' + @CRLF
		AS NVARCHAR(MAX)) AS OutputText
	INTO #TestOutput

	EXEC tSQLt.AssertEqualsTable '#TestOutput', 'SqlUtils.tSQLt.CaptureOutputLog'
END
GO
