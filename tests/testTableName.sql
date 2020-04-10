USE SqlUtils
GO

EXEC tSQLt.NewTestClass 'testTableName';
GO

CREATE PROCEDURE testTableName.[test empty our table]
AS
BEGIN
	EXEC tSQLt.ExpectException 'Invalid or missing table name in parameter @ourTableName = ''''', 16, 1

	EXEC CompareData '', ''
END
GO

CREATE PROCEDURE testTableName.[test our table isn't a table]
AS
BEGIN
	EXEC tSQLt.ExpectException 'Cannot find table [SqlUtils].[dbo].[CompareData]', 16, 1

	EXEC CompareData 'SqlUtils.dbo.CompareData', 'a..a'
END
GO

CREATE PROCEDURE testTableName.[test our table doesn't have primary keys, and no join spec]
AS
BEGIN
	EXEC tSQLt.ExpectException 'There are no primary keys for table [SqlUtilsTests_C].[dbo].[AddressTypes]. One or more primary keys or a @join parameter are required to join the tables to be compared.', 16, 1

	EXEC CompareData 'SqlUtilsTests_C..AddressTypes', 'SqlUtilsTests_A..AddressTypes'
END
GO

CREATE PROCEDURE testTableName.[test empty their table]
AS
BEGIN
	EXEC tSQLt.ExpectException 'Invalid or missing table name in parameter @theirTableName = ''''', 16, 1

	EXEC CompareData 'a..a', ''
END
GO

CREATE PROCEDURE testTableName.[test missing table in our table]
AS
BEGIN
	EXEC tSQLt.ExpectException 'Invalid or missing table name in parameter @ourTableName = ''a..''', 16, 1

	EXEC CompareData 'a..', ''
END
GO

CREATE PROCEDURE testTableName.[test missing table in their table]
AS
BEGIN
	EXEC tSQLt.ExpectException 'Invalid or missing table name in parameter @theirTableName = ''b..''', 16, 1

	EXEC CompareData 'a..a', 'b..'
END
GO

CREATE PROCEDURE testTableName.[test missing database in our table]
AS
BEGIN
	EXEC tSQLt.ExpectException 'Invalid or missing database name in parameter @ourTableName = ''a''', 16, 1

	EXEC CompareData 'a', ''
END
GO

CREATE PROCEDURE testTableName.[test missing database in their table]
AS
BEGIN
	EXEC tSQLt.ExpectException 'Invalid or missing database name in parameter @theirTableName = ''b''', 16, 1

	EXEC CompareData 'a..a', 'b'
END
GO
