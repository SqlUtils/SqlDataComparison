SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [internals].[CompareAndReconcile]
	@our_table_name sysname,
	@their_table_name sysname,
	@use_columns nvarchar(max) = null,
	@join_columns nvarchar(max) = null,
	@rename_columns nvarchar(max) = null,
	@import int = null, -- > 0 means import; < 0 means export
	@added_rows bit = null,
	@deleted_rows bit = null,
	@changed_rows bit = null
AS
BEGIN
	SET NOCOUNT ON;

	-- loop var
	DECLARE @i INT

	-- holds SQL for the current operation
	DECLARE @params NVARCHAR(MAX)
	DECLARE @sql NVARCHAR(MAX)

	DECLARE @msg NVARCHAR(MAX)

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

	/*
	 * Check for table existence
	 */
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

	/*
	 * Get table columns
	 */
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

	/*
	 * Filter to @use_columns
	 */
	IF @use_columns IS NOT NULL
	BEGIN
		CREATE TABLE #use_columns
		(
			name sysname
		)

		INSERT INTO #use_columns
		SELECT * FROM internals.SplitColumnNames(@use_columns)
		SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

		IF @error <> 0
		BEGIN
			RAISERROR('*** Illegal or missing column names found in @use_columns ''%s'' (quote column names using [...] if necessary)', 16, 1, @use_columns)
			GOTO complete
		END

		DECLARE @illegal_columns NVARCHAR(MAX)

		-- gather illegal column names (if any) into a single string using FOR XML PATH; have to use CTE with this in order to get the count
		SET @rowcount = 0;
		WITH IllegalColumns_CTE (name)
		AS
		(
			SELECT uc.name
			FROM #use_columns uc
			LEFT OUTER JOIN #columns c
			ON uc.name = c.name
			WHERE c.name IS NULL
		)
		SELECT
			@illegal_columns = STUFF(
			(
				SELECT ', ''' + name + ''''
				FROM IllegalColumns_CTE
				FOR XML PATH('')
			), 1, 2, ''),
			@rowcount = (SELECT COUNT(*) FROM IllegalColumns_CTE)

		IF @illegal_columns <> ''
		BEGIN
			IF @rowcount = 1
				SET @msg = 'Column name %s specified in @use_columns does not exist in %s'
			ELSE
				SET @msg = 'Column names %s specified in @use_columns do not exist in %s'
			RAISERROR(@msg, 16, 1, @illegal_columns, @local_full_table_name)
			GOTO complete
		END

		-- apply filter
		DELETE c
		FROM #columns c
		LEFT OUTER JOIN #use_columns uc
		ON c.name = uc.name
		WHERE uc.name IS NULL
	END

	/*
	 * Get table primay key columns
	 */
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
	SELECT @JOIN = @JOIN + '%0 JOIN ' + @remote_full_table_name + ' [theirs]' + @CRLF

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
	IF @import <> 0
	BEGIN
		IF @import > 0 SELECT @lower = 'import', @Upper = 'Import'
		ELSE SELECT @lower = 'export', @Upper = 'Export'

		-- determine whether there is an identity column (must check this on the target side side of the data transfer)
		DECLARE @has_identity BIT = 0

		-- there can only be one
		CREATE TABLE #identity_columns
		(
			column_id int,
			name sysname
		)

		-- only need to work with identity columns for add and change, not deletes
		IF @added_rows = 1 OR @changed_rows = 1
		BEGIN
			SET @params =
				'@schema sysname,' + @CRLF +
				'@table sysname'
			SET @sql =
				'SELECT c.column_id, c.name' + @CRLF +
				'FROM %0.sys.schemas s' + @CRLF +
				'INNER JOIN %0.sys.objects o' + @CRLF +
				'ON o.schema_id = s.schema_id' + @CRLF +
				'INNER JOIN %0.sys.columns c' + @CRLF +
				'ON c.object_id = o.object_id' + @CRLF +
				'INNER JOIN %0.sys.identity_columns ic' + @CRLF +
				'ON ic.object_id = o.object_id' + @CRLF +
				'AND ic.column_id = c.column_id' + @CRLF +
				'WHERE s.name = @schema' + @CRLF +
				'AND o.name = @table'

			DECLARE @target_schema sysname = CASE WHEN @import > 0 THEN @our_schema ELSE @their_schema END
			DECLARE @target_table sysname = CASE WHEN @import > 0 THEN @our_table ELSE @their_table END

			SET @sql = REPLACE(@sql, '%0', CASE WHEN @import > 0 THEN @local_database_part ELSE @remote_database_part END)

			INSERT INTO #identity_columns (column_id, name)
			EXEC sp_executesql @sql, @params, @target_schema, @target_table
			SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

			IF @error <> 0 GOTO complete

			IF @rowcount > 0 SET @has_identity = 1
		END

		DECLARE @from sysname = CASE WHEN @import > 0 THEN '[theirs]' ELSE '[ours]' END
		DECLARE @to sysname = CASE WHEN @import > 0 THEN '[ours]' ELSE '[theirs]' END

		/*
		 * ADDED ROWS
		 */
		IF @added_rows = 1
		BEGIN
			RAISERROR('%s%sing added rows...', 0, 1, @CRLF, @Upper)

			SET @sql = CASE WHEN @has_identity = 1 THEN 'SET IDENTITY_INSERT %0 ON;' + @CRLF + @CRLF ELSE '' END

			SET @sql = @sql + 'INSERT INTO %0 (' + @CRLF

			SELECT @sql = @sql + @TAB + '[' + #columns.name + '],' + @CRLF
			FROM #columns

			SELECT @sql = SUBSTRING(@sql, 1, LEN(@sql) - LEN(@CRLF) - 1) + @CRLF

			SELECT @sql = @sql + ')' + @CRLF

			SELECT @sql = @sql + 'SELECT' + @CRLF

			SELECT @sql = @sql + @TAB + '%2.[' + #columns.name + '],' + @CRLF
			FROM #columns

			SELECT @sql = SUBSTRING(@sql, 1, LEN(@sql) - LEN(@CRLF) - 1) + @CRLF

			SELECT @sql = @sql + REPLACE(@JOIN, '%0', 'FULL OUTER')

			SET @i = 0
			SELECT
				@sql = @sql +
					CASE WHEN @i = 0 THEN 'WHERE ' ELSE '  AND ' END +
					'%1.[' + #key_columns.name + '] IS NULL' + @CRLF,
				@i = @i + 1
			FROM #key_columns

			-- do not add SQL to explicitly turn off IDENTITY_INSERT, as it loses the rowcount and is turned off automatically when we leave the scope of the EXEC() anyway

			SET @sql = REPLACE(REPLACE(REPLACE(@sql, '%0', CASE WHEN @import > 0 THEN @local_full_table_name ELSE @remote_full_table_name END), '%1', @to), '%2', @from);

			--PRINT @sql + @CRLF

			SET NOCOUNT OFF;
			EXEC (@sql)
			SELECT @error = @@ERROR, @rowcount = @@ROWCOUNT
			SET NOCOUNT ON;

			IF @error = 0
				RAISERROR('Requested %s completed with no errors. Transferred %d rows from %s into %s.', 0, 1, @lower, @rowcount, @from, @to)
		END

		/*
		 * DELETED ROWS
		 */
		IF @deleted_rows = 1
		BEGIN
			RAISERROR('%s%sing deleted rows...', 0, 1, @CRLF, @Upper)

			SET @sql = 'DELETE %1' + @CRLF

			SELECT @sql = @sql + REPLACE(@JOIN, '%0', 'FULL OUTER')

			SET @i = 0
			SELECT
				@sql = @sql +
					CASE WHEN @i = 0 THEN 'WHERE ' ELSE '   OR ' END +
					'%1.[' + #key_columns.name + '] IS NOT NULL AND %2.[' + #key_columns.name + '] IS NULL' + @CRLF,
				@i = @i + 1
			FROM #key_columns

			SET @sql = REPLACE(REPLACE(@sql, '%1', @to), '%2', @from);

			--PRINT @sql + @CRLF

			SET NOCOUNT OFF;
			EXEC (@sql)
			SELECT @error = @@ERROR, @rowcount = @@ROWCOUNT
			SET NOCOUNT ON;

			IF @error = 0
				RAISERROR('Requested %s completed with no errors. Deleted %d rows from %s.', 0, 1, @lower, @rowcount, @to)
		END

		/*
		 * CHANGED ROWS
		 */
		IF @deleted_rows = 1
		BEGIN
			RAISERROR('%s%sing changed rows...', 0, 1, @CRLF, @Upper)

			SET @sql = 'UPDATE %1' + @CRLF

			SET @i = 0
			SELECT
				@sql = @sql + @TAB + CASE WHEN @i = 0 THEN 'SET ' ELSE @TAB END + '[' + #columns.name + '] = %2.[' + #columns.name + '],' + @CRLF,
				@i = @i + 1
			FROM #columns
			LEFT OUTER JOIN #identity_columns
			ON #columns.column_id = #identity_columns.column_id
			WHERE #identity_columns.column_id IS NULL

			SELECT @sql = SUBSTRING(@sql, 1, LEN(@sql) - LEN(@CRLF) - 1) + @CRLF

			SELECT @sql = @sql + REPLACE(@JOIN, '%0', 'INNER')

			SET @i = 0
			SELECT
				@sql = @sql +
					CASE WHEN @i = 0 THEN 'WHERE ' ELSE '   OR ' END +
					'[ours].[' + #columns.name + '] IS NULL AND [theirs].[' + #columns.name + '] IS NOT NULL' + @CRLF +
					'   OR [ours].[' + #columns.name + '] IS NOT NULL AND [theirs].[' + #columns.name + '] IS NULL' + @CRLF +
					'   OR [ours].[' + #columns.name + '] <> [theirs].[' + #columns.name + ']' + @CRLF,
				@i = @i + 1
			FROM #columns
			LEFT OUTER JOIN #key_columns
			ON #columns.column_id = #key_columns.column_id
			WHERE #key_columns.column_id IS NULL

			-- do not add SQL to explicitly turn off IDENTITY_INSERT, as it loses the rowcount and is turned off automatically when we leave the scope of the EXEC() anyway

			SET @sql = REPLACE(REPLACE(REPLACE(@sql, '%0', CASE WHEN @import > 0 THEN @local_full_table_name ELSE @remote_full_table_name END), '%1', @to), '%2', @from);

			--PRINT @sql + @CRLF

			SET NOCOUNT OFF;
			EXEC (@sql)
			SELECT @error = @@ERROR, @rowcount = @@ROWCOUNT
			SET NOCOUNT ON;

			IF @error = 0
				RAISERROR('Requested %s completed with no errors. Updated %d rows in %s with data from %s.', 0, 1, @lower, @rowcount, @to, @from)
		END
	END

	/*
	 * DATA COMPARE
	 */

	SET @sql = 'SELECT '

	SET @sql = @sql + '''OURS >>>'' AS [ ],' + @CRLF
	SELECT @sql = @sql + @TAB + '   [ours].[' + #columns.name + '],' + @CRLF
	FROM #columns

	SET @sql = @sql + @TAB + '   ''THEIRS >>>'' AS [ ],' + @CRLF
	SELECT @sql = @sql + @TAB + '   [theirs].[' + #columns.name + '],' + @CRLF
	FROM #columns

	SELECT @sql = SUBSTRING(@sql, 1, LEN(@sql) - LEN(@CRLF) - 1) + @CRLF

	SELECT @sql = @sql + REPLACE(@JOIN, '%0', 'FULL OUTER')

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
			'   OR [ours].[' + #columns.name + '] <> [theirs].[' + #columns.name + ']' + @CRLF
	FROM #columns
	LEFT OUTER JOIN #key_columns
	ON #columns.column_id = #key_columns.column_id
	WHERE #key_columns.column_id IS NULL

	--PRINT @sql + @CRLF

	EXEC (@sql)

	IF @@ROWCOUNT > 0
		RAISERROR('Data differences found between OURS >>> %s and THEIRS >>> %s.%s - Switch to results window to view differences.%s - Call [Import|Export][AddedRows|DeletedRows|ChangedRows|All] (e.g. ImportAddedRows) with the same arguments to transfer changes.%s', 16, 1, @local_full_table_name, @remote_full_table_name, @CRLF, @CRLF, @CRLF)
	ELSE
		RAISERROR('%sNo data differences found between OURS >>> %s and THEIRS >>> %s.', 0, 1, @CRLF, @local_full_table_name, @remote_full_table_name)

complete:
END
GO
