SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [internals].[CompareAndReconcile]
	@our_table_name sysname,
	@their_table_name sysname,
	@import_added_rows int = null,
	@import_deleted_rows int = null,
	@import_changed_rows int = null
AS
BEGIN
	SET NOCOUNT ON;

	-- loop var
	DECLARE @i INT

	-- holds SQL for the current operation
	DECLARE @params NVARCHAR(MAX)
	DECLARE @sql NVARCHAR(MAX)

	-- return values
	DECLARE @error INT
	DECLARE @rowcount INT

	/*
	 * parse @our_table_name
	 */
	DECLARE @our_server sysname
	DECLARE @our_database sysname
	DECLARE @our_schema sysname
	DECLARE @our_table sysname
	DECLARE @local_database_part sysname
	DECLARE @local_full_table_name sysname

	EXEC internals.ParseQualifiedTableName
		@qualified_table_name = @our_table_name,
		@server = @our_server OUTPUT,
		@database = @our_database OUTPUT,
		@schema = @our_schema OUTPUT,
		@table = @our_table OUTPUT,
		@full_database_part = @local_database_part OUTPUT,
		@full_table_name = @local_full_table_name OUTPUT,
		@param_name = '@our_table_name'

	IF @@ERROR <> 0 GOTO complete

	/*
	 * parse @their_table_name
	 */
	DECLARE @their_server sysname
	DECLARE @their_database sysname
	DECLARE @their_schema sysname
	DECLARE @their_table sysname
	DECLARE @remote_database_part sysname
	DECLARE @remote_full_table_name sysname

	EXEC internals.ParseQualifiedTableName
		@qualified_table_name = @their_table_name,
		@server = @their_server OUTPUT,
		@database = @their_database OUTPUT,
		@schema = @their_schema OUTPUT,
		@table = @their_table OUTPUT,
		@full_database_part = @remote_database_part OUTPUT,
		@full_table_name = @remote_full_table_name OUTPUT,
		@param_name = '@their_table_name'

	IF @@ERROR <> 0 GOTO complete

	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)
	DECLARE @TAB CHAR(1) = CHAR(9)

	SET @params =
		'@schema sysname,' + @CRLF +
		'@table sysname,' + @CRLF +
		'@object_id int = null output'
	SET @sql =
		'SELECT @object_id = o.object_id' + @CRLF +
		'FROM ' + @local_database_part + '.sys.objects o' + @CRLF +
		'INNER JOIN ' + @local_database_part + '.sys.schemas s' + @CRLF +
		'ON o.schema_id = s.schema_id' + @CRLF +
		'AND s.name = @schema' + @CRLF +
		'WHERE o.name = @table' + @CRLF

	EXEC sp_executesql @sql, @params, @our_schema, @our_table
	SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

	IF @error <> 0 GOTO complete

	IF @rowcount = 0
	BEGIN
		RAISERROR('Cannot find table %s', 16, 1, @local_full_table_name)
		GOTO complete
	END

	CREATE TABLE #columns
	(
		column_id int,
		name sysname
	)

	SET @params =
		'@schema sysname,' + @CRLF +
		'@table sysname'
	SET @sql =
		'SELECT c.column_id, c.name' + @CRLF +
		'FROM ' + @local_database_part + '.sys.objects o' + @CRLF +
		'INNER JOIN ' + @local_database_part + '.sys.schemas s' + @CRLF +
		'ON o.schema_id = s.schema_id' + @CRLF +
		'AND s.name = @schema' + @CRLF +
		'INNER JOIN ' + @local_database_part + '.sys.columns c' + @CRLF +
		'ON o.object_id = c.object_id' + @CRLF +
		'WHERE o.name = @table'
		
	INSERT INTO #columns (column_id, name)
	EXEC sp_executesql @sql, @params, @our_schema, @our_table
	SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

	IF @error <> 0 GOTO complete

	IF @rowcount = 0
	BEGIN
		RAISERROR('There are no columns for table %s', 16, 1, @local_full_table_name)
		GOTO complete
	END

	CREATE TABLE #key_columns
	(
		column_id int,
		name sysname
	)

	SET @params =
		'@schema sysname,' + @CRLF +
		'@table sysname'
	SET @sql =
		'SELECT c.column_id, c.name' + @CRLF +
		'FROM ' + @local_database_part + '.sys.objects o' + @CRLF +
		'INNER JOIN ' + @local_database_part + '.sys.schemas s' + @CRLF +
		'ON o.schema_id = s.schema_id' + @CRLF +
		'AND s.name = @schema' + @CRLF +
		'INNER JOIN ' + @local_database_part + '.sys.indexes i' + @CRLF +
		'ON o.object_id = i.object_id' + @CRLF +
		'AND i.is_primary_key = 1' + @CRLF +
		'INNER JOIN ' + @local_database_part + '.sys.index_columns ic' + @CRLF +
		'ON i.object_id = ic.object_id' + @CRLF +
		'AND i.index_id = ic.index_id' + @CRLF +
		'INNER JOIN ' + @local_database_part + '.sys.columns c' + @CRLF +
		'ON c.column_id = ic.column_id' + @CRLF +
		'AND c.object_id = o.object_id' + @CRLF +
		'WHERE o.name = @table'
		
	INSERT INTO #key_columns (column_id, name)
	EXEC sp_executesql @sql, @params, @our_schema, @our_table
	SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

	IF @error <> 0 GOTO complete

	IF @rowcount = 0
	BEGIN
		RAISERROR('There are no primary keys for table %s. One or more primary keys are required to join the tables to be compared.', 16, 1, @local_full_table_name)
		GOTO complete
	END

	/*
	 * CREATE THE COMMON JOIN SQL
	 */
	DECLARE @JOIN NVARCHAR(MAX)

	SELECT @JOIN = 'FROM ' + @local_full_table_name + ' [ours]' + @CRLF
	SELECT @JOIN = @JOIN + 'FULL OUTER JOIN ' + @remote_full_table_name + ' [theirs]' + @CRLF

	SET @i = 0
	SELECT
		@JOIN = @JOIN + CASE WHEN @i = 0 THEN 'ON' ELSE 'AND' END + ' [ours].[' + #key_columns.name + '] = [theirs].[' + #key_columns.name + ']' + @CRLF,
		@i = @i + 1
	FROM #key_columns

	DECLARE @lower NVARCHAR(MAX)
	DECLARE @Upper NVARCHAR(MAX)

	/*
	 * THEIRS TO OURS AND OURS TO THEIRS
	 */
	IF @import_added_rows <> 0
	BEGIN
		IF @import_added_rows > 0 SELECT @lower = 'import', @Upper = 'Import'
		ELSE SELECT @lower = 'export', @Upper = 'Export'

		RAISERROR('%sing added rows...', 0, 1, @Upper)

		DECLARE @has_identity BIT = 0

		SET @params =
			'@schema sysname,' + @CRLF +
			'@table sysname,' + @CRLF +
			'@has_identity sysname output'
		SET @sql =
			'SELECT @has_identity = 1' + @CRLF +
			'FROM %0.sys.identity_columns ic' + @CRLF +
			'INNER JOIN %0.sys.objects o' + @CRLF +
			'ON ic.object_id = o.object_id' + @CRLF +
			'INNER JOIN %0.sys.schemas s' + @CRLF +
			'ON o.schema_id = s.schema_id' + @CRLF +
			'AND s.name = @schema' + @CRLF +
			'WHERE o.name = @table' + @CRLF

		DECLARE @to_schema sysname = CASE WHEN @import_added_rows > 0 THEN @our_schema ELSE @their_schema END
		DECLARE @to_table sysname = CASE WHEN @import_added_rows > 0 THEN @our_table ELSE @their_table END

		SET @sql = REPLACE(@sql, '%0', CASE WHEN @import_added_rows > 0 THEN @local_database_part ELSE @remote_database_part END)

		EXEC sp_executesql @sql, @params, @to_schema, @to_table, @has_identity OUTPUT
		SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

		IF @error <> 0 GOTO complete

		SET @sql = CASE WHEN @has_identity = 1 THEN 'SET IDENTITY_INSERT %0 ON;' + @CRLF + @CRLF ELSE '' END

		SET @sql = @sql + 'INSERT INTO %0 (' + @CRLF

		SELECT @sql = @sql + @TAB + '[' + #columns.name + '],' + @CRLF
		FROM #columns

		SELECT @sql = SUBSTRING(@sql, 1, LEN(@sql) - LEN(@CRLF) - 1) + @CRLF

		SELECT @sql = @sql + ')' + @CRLF

		SELECT @sql = @sql + 'SELECT' + @CRLF

		SELECT @sql = @sql + @TAB + '%1.[' + #columns.name + '],' + @CRLF
		FROM #columns

		SELECT @sql = SUBSTRING(@sql, 1, LEN(@sql) - LEN(@CRLF) - 1) + @CRLF

		SELECT @sql = @sql + @JOIN

		SET @i = 0
		SELECT
			@sql = @sql +
				CASE WHEN @i = 0 THEN 'WHERE ' ELSE '  AND ' END +
				'%2.[' + #key_columns.name + '] IS NULL' + @CRLF,
			@i = @i + 1
		FROM #key_columns

		-- don't explicitly turn off IDENTITY_INSERT as it loses the rowcount and is
		-- turned off automatically when we leave the scope of the EXEC()

		--PRINT @sql+@CRLF

		DECLARE @from sysname = CASE WHEN @import_added_rows > 0 THEN '[theirs]' ELSE '[ours]' END
		DECLARE @to sysname = CASE WHEN @import_added_rows > 0 THEN '[ours]' ELSE '[theirs]' END

		DECLARE @IMPORT_SQL NVARCHAR(MAX)

		SET @IMPORT_SQL = REPLACE(REPLACE(REPLACE(@sql, '%0', CASE WHEN @import_added_rows > 0 THEN @local_full_table_name ELSE @remote_full_table_name END), '%1', @from), '%2', @to);

		--PRINT @IMPORT_SQL+@CRLF

		SET NOCOUNT OFF;
		EXEC (@IMPORT_SQL)
		SELECT @error = @@ERROR, @rowcount = @@ROWCOUNT
		SET NOCOUNT ON;

		IF @error = 0
			RAISERROR('Requested %s completed with no errors. Transferred %d rows from %s into %s.', 0, 1, @lower, @rowcount, @from, @to)
	END

	/*
	 * DISPLAY THE DATA DIFFERENCES
	 */

	SET @sql = 'SELECT '

	SET @sql = @sql + '''OURS >>>'' AS [ ],' + @CRLF
	SELECT @sql = @sql + @TAB + '   [ours].[' + #columns.name + '],' + @CRLF
	FROM #columns

	SET @sql = @sql + @TAB + '   ''THEIRS >>>'' AS [ ],' + @CRLF
	SELECT @sql = @sql + @TAB + '   [theirs].[' + #columns.name + '],' + @CRLF
	FROM #columns

	SELECT @sql = SUBSTRING(@sql, 1, LEN(@sql) - LEN(@CRLF) - 1) + @CRLF

	SELECT @sql = @sql + @JOIN

	SET @i = 0
	SELECT
		@sql = @sql +
			CASE WHEN @i = 0 THEN 'WHERE ' ELSE '   OR ' END +
			'[ours].[' + #key_columns.name + '] IS NULL AND [theirs].[' + #key_columns.name + '] IS NOT NULL' + @CRLF +
			'   OR [ours].[' + #key_columns.name + '] IS NOT NULL AND [theirs].[' + #key_columns.name + '] IS NULL' + @CRLF,
		@i = @i + 1
	FROM #key_columns

	SELECT
		@sql = @sql +
			'   OR [ours].[' + #columns.name + '] IS NULL AND [theirs].[' + #columns.name + '] IS NOT NULL' + @CRLF +
			'   OR [ours].[' + #columns.name + '] IS NOT NULL AND [theirs].[' + #columns.name + '] IS NULL' + @CRLF +
			'   OR [ours].[' + #columns.name + '] <> [theirs].[' + #columns.name + ']' + @CRLF,
		@i = @i + 1
	FROM #columns
	LEFT OUTER JOIN #key_columns
	ON #columns.column_id = #key_columns.column_id
	WHERE #key_columns.column_id IS NULL

	--PRINT @sql + @CRLF

	EXEC (@sql)

	IF @@ROWCOUNT > 0
		RAISERROR('Data differences found between OURS >>> %s and THEIRS >>> %s.%s - Switch to results window to view differences.%s - Call [Import|Export][AddedRows|DeletedRows|ChangedRows|All] (e.g. ImportAddedRows) with the same arguments to transfer changes.%s', 16, 1, @local_full_table_name, @remote_full_table_name, @CRLF, @CRLF, @CRLF)
	ELSE
		RAISERROR('No data differences found between OURS >>> %s and THEIRS >>> %s.', 0, 1, @local_full_table_name, @remote_full_table_name)

complete:
END
