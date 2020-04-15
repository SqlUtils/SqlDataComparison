USE SqlUtilsTests_A

DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

DECLARE @SQL NVARCHAR(MAX)

CREATE TABLE SillyNames (
	LongestName sysname,
	LongName sysname,
	DaftName1 sysname,
	DaftName2 sysname
)

INSERT INTO SillyNames
VALUES (
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]',
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]]]]' +
	']]]]]]]''',
	'[crazy].mighty.''name''',
	'Another.[Fool''s].quest'
)

DECLARE @longestName sysname
DECLARE @longName sysname
DECLARE @daftName1 sysname
DECLARE @daftName2 sysname

SELECT
	@longestName = LongestName,
	@longName = LongName,
	@daftName1 = DaftName1,
	@daftName2 = DaftName2
FROM SillyNames

SET @SQL = 
	'CREATE SCHEMA ' + QUOTENAME(@longestname) + @CRLF
EXEC(@SQL)

SET @SQL = 
	'CREATE TABLE ' + QUOTENAME(@longestname) + '.' + QUOTENAME(@longestname) + ' (' + @CRLF +
	'	' + QUOTENAME(@longestname) + ' INT,' + @CRLF +
	'	' + QUOTENAME(@daftname1) + ' INT,' + @CRLF +
	'	' + QUOTENAME(@daftname2) + ' NVARCHAR(50)' + @CRLF +
	')' + @CRLF
EXEC(@SQL)

SET @SQL = 
	'INSERT INTO ' + QUOTENAME(@longestname) + '.' + QUOTENAME(@longestname) + @CRLF +
	'VALUES (1, 1, ''Home''), (2, 1, ''Work'')' + @CRLF
EXEC(@SQL)

USE SqlUtilsTests_C

SET @SQL = 
	'CREATE TABLE ' + QUOTENAME(@longname) + ' (' + @CRLF +
	'	' + QUOTENAME(@daftname2) + ' INT,' + @CRLF +
	'	' + QUOTENAME(@longestname) + ' INT,' + @CRLF +
	'	' + QUOTENAME(@daftname1) + ' NVARCHAR(50)' + @CRLF +
	')' + @CRLF
EXEC(@SQL)

SET @SQL = 
	'INSERT INTO ' + QUOTENAME(@longname) + @CRLF +
	'VALUES (1, 1, ''Home''), (2, 1, ''Wxrk'')' + @CRLF
EXEC(@SQL)
