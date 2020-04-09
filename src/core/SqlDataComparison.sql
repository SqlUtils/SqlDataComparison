SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [core].[SqlDataComparison]
	@our_table_name sysname,
	@their_table_name sysname,
	@default_db_name sysname = null,
	@map nvarchar(max) = null,
	@join nvarchar(max) = null,
	@use nvarchar(max) = null,
	@where nvarchar(max) = null,
	@import int = null, -- > 0 means import; < 0 means export
	@added_rows bit = null,
	@deleted_rows bit = null,
	@changed_rows bit = null,
	@show_sql bit = null,
	@interleave bit = null
AS
BEGIN
	SET NOCOUNT ON;

	-- loop var
	DECLARE @i INT

	-- holds SQL for the current operation
	DECLARE @params NVARCHAR(MAX)
	DECLARE @sql NVARCHAR(MAX)

	-- use to collect @@ return values
	DECLARE @error INT
	DECLARE @rowcount INT

	/*
	 * confirm @where is approximately valid
	 */
	IF @where IS NOT NULL AND CHARINDEX('ours', @where) = 0 AND CHARINDEX('theirs', @where) = 0
	BEGIN
		RAISERROR('Columns in @where parameter "%s" should be specified using ours.<colname> or theirs.<colname>', 16, 1, @where)
		GOTO complete
	END

	/*
	 * parse @our_table_name
	 */
	DECLARE @our_server sysname
	DECLARE @our_database sysname
	DECLARE @our_schema sysname
	DECLARE @our_table sysname
	DECLARE @local_database_part sysname
	DECLARE @local_full_table_name sysname

	EXEC internals.ValidateQualifiedTableName
		@qualified_table_name = @our_table_name,
		@default_db_name = @default_db_name,
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

	-- do not apply default table name to theirs (it becomes more confusing than helpful when user sends db.table instead of db..table by mistake)
	EXEC internals.ValidateQualifiedTableName
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
	 * Get local table columns
	 */
	DECLARE @local_columns internals.ColumnsTable

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
		
	INSERT INTO @local_columns (column_id, name)
	EXEC sp_executesql @sql, @params, @our_schema, @our_table
	SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

	IF @error <> 0 GOTO complete

	IF @rowcount = 0
	BEGIN
		RAISERROR('There are no columns for table %s', 16, 1, @local_full_table_name)
		GOTO complete
	END

	/*
	 * Validate @use
	 */
	DECLARE @use_columns internals.ColumnsTable

	IF @use IS NULL
	BEGIN
		INSERT INTO @use_columns (column_id, name)
		SELECT column_id, name
		FROM @local_columns
	END
	ELSE
	BEGIN
		INSERT INTO @use_columns (name)
		SELECT name FROM internals.SplitColumnNames(@use)
		SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

		IF @error <> 0
		BEGIN
			RAISERROR('*** Illegal or missing column names found in @use ''%s'' (quote column names using [...] if necessary)', 16, 1, @use)
			GOTO complete
		END

		EXEC internals.ValidateColumns
			@use_columns, @local_columns,
			'''', '''', 
			'Column name %s specified in @use does not exist in %s',
			'Column names %s specified in @use do not exist in %s',
			@local_full_table_name
		IF @@ERROR <> 0 GOTO complete

		-- fill out @use_columns and give canonical name
		UPDATE uc
		SET column_id = c.column_id, name = c.name
		FROM @use_columns uc
		INNER JOIN @local_columns c
		ON uc.name = c.name
	END

	/*
	 * Collect remote columns
	 */
	DECLARE @remote_columns internals.ColumnsTable

	SET @params =
		'@schema sysname,' + @CRLF +
		'@table sysname'
	SET @sql =
		'SELECT c.column_id, c.name' + @CRLF +
		'FROM ' + @remote_database_part + '.sys.objects o' + @CRLF +
		'INNER JOIN ' + @remote_database_part + '.sys.schemas s' + @CRLF +
		'ON o.schema_id = s.schema_id' + @CRLF +
		'AND s.name = @schema' + @CRLF +
		'INNER JOIN ' + @remote_database_part + '.sys.columns c' + @CRLF +
		'ON o.object_id = c.object_id' + @CRLF +
		'WHERE o.name = @table'
		
	INSERT INTO @remote_columns (column_id, name)
	EXEC sp_executesql @sql, @params, @their_schema, @their_table
	SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

	IF @error <> 0 GOTO complete

	IF @rowcount = 0
	BEGIN
		RAISERROR('There are no columns for table %s', 16, 1, @remote_full_table_name)
		GOTO complete
	END

	/*
	 * Validate and process column name remapping
	 */
	-- NB @mapped_columns contains local column id with mapped remote column name
	DECLARE @mapped_columns internals.ColumnsTable

	IF @map IS NULL
	BEGIN
		INSERT INTO @mapped_columns (column_id, name)
		SELECT column_id, name
		FROM @local_columns
	END
	ELSE
	BEGIN
		CREATE TABLE #column_mapping
		(
			[name] sysname,
			rename sysname
		)

		INSERT INTO #column_mapping
		SELECT [name], rename
		FROM internals.SplitColumnMap(@map)
		SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

		IF @error <> 0
		BEGIN
			RAISERROR('*** Illegal data found in @map ''%s'' (use ''our_col1,their_col1;our_col2,their_col2'', quoting column names using [...] if necessary)', 16, 1, @map)
			GOTO complete
		END

		-- validate mapping source columns
		DECLARE @map_source internals.ColumnsTable

		INSERT INTO @map_source (name)
		SELECT name
		FROM #column_mapping

		EXEC internals.ValidateColumns
			@map_source, @local_columns,
			'''', '''',
			'Source column name %s specified in @map does not exist in %s',
			'Source column names %s specified in @map do not exist in %s',
			@local_full_table_name
		IF @@ERROR <> 0 GOTO complete

		-- validate mapping target columns
		DECLARE @map_target internals.ColumnsTable

		INSERT INTO @map_target (name)
		SELECT rename
		FROM #column_mapping

		EXEC internals.ValidateColumns
			@map_target, @remote_columns,
			'''', '''',
			'Target column name %s specified in @map does not exist in %s',
			'Target column names %s specified in @map do not exist in %s',
			@remote_full_table_name
		IF @@ERROR <> 0 GOTO complete

		-- we already know that mapped columns do map, so we can safely convert to the canoncial remote name here
		INSERT INTO @mapped_columns (column_id, name)
		SELECT lc.column_id, ISNULL(rc.name, lc.name)
		FROM @local_columns lc
		LEFT OUTER JOIN #column_mapping m
		ON lc.name = m.name
		LEFT OUTER JOIN @remote_columns rc
		ON m.rename = rc.name
	END

	/*
	 * Confirm that all columns to be used exist remotely
	 */
	DECLARE @mapped_use_columns internals.ColumnsTable

	INSERT INTO @mapped_use_columns (name)
	SELECT m.name
	FROM @use_columns u
	INNER JOIN @mapped_columns m
	ON u.column_id = m.column_id

	EXEC internals.ValidateColumns
		@mapped_use_columns, @remote_columns,
		'[', ']', -- use [] to quote these names, as we know they exist locally
		'Required column %s does not exist in %s',
		'Required columns %s do not exist in %s',
		@remote_full_table_name
	IF @@ERROR <> 0 GOTO complete

	/*
	 * Holds table primary key columns or user-specified join columns
	 */
	DECLARE @key_columns internals.ColumnsTable

	/*
	 * Use @join for join instead of table primary keys, if provided
	 */
	IF @join IS NOT NULL
	BEGIN
		DECLARE @join_columns internals.ColumnsTable

		INSERT INTO @join_columns (name)
		SELECT name FROM internals.SplitColumnNames(@join)
		SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

		IF @error <> 0
		BEGIN
			RAISERROR('*** Illegal or missing column names found in @join ''%s'' (quote column names using [...] if necessary)', 16, 1, @join)
			GOTO complete
		END

		EXEC internals.ValidateColumns
			@join_columns, @use_columns,
			'''', '''',
			'Column name %s specified in @join does not exist in %s',
			'Column names %s specified in @join do not exist in %s',
			@local_full_table_name
		IF @@ERROR <> 0 GOTO complete

		INSERT INTO @key_columns (column_id, name)
		SELECT c.column_id, c.name
		FROM @use_columns c
		INNER JOIN @join_columns jc
		ON c.name = jc.name
	END
	ELSE
	BEGIN
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
		
		INSERT INTO @key_columns (column_id, name)
		EXEC sp_executesql @sql, @params, @our_schema, @our_table
		SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

		IF @error <> 0 GOTO complete

		IF @rowcount = 0
		BEGIN
			RAISERROR('There are no primary keys for table %s. One or more primary keys or a @join parameter are required to join the tables to be compared.', 16, 1, @local_full_table_name)
			GOTO complete
		END
	END

	/*
	 * CREATE THE COMMON JOIN SQL
	 */
	DECLARE @join_sql NVARCHAR(MAX)

	SELECT @join_sql = 'FROM ' + @local_full_table_name + ' [ours]' + @CRLF
	SELECT @join_sql = @join_sql + '%0 JOIN ' + @remote_full_table_name + ' [theirs]' + @CRLF

	SET @i = 0
	SELECT
		@join_sql = @join_sql + CASE WHEN @i = 0 THEN 'ON' ELSE 'AND' END + ' [ours].[' + kc.name + '] = [theirs].[' + m.name + ']' + @CRLF,
		@i = @i + 1
	FROM @key_columns kc
	INNER JOIN @mapped_columns m
	ON kc.column_id = m.column_id

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

		-- we use a standard shape table, but there can only be one identity column
		DECLARE @identity_columns internals.ColumnsTable

		-- only need to work with identity columns for adds and changes, not deletes
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

			INSERT INTO @identity_columns (column_id, name)
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

			SELECT @sql = @sql + @TAB + '[' + CASE WHEN @import > 0 THEN uc.name ELSE m.name END + '],' + @CRLF
			FROM @use_columns uc
			INNER JOIN @mapped_columns m
			ON uc.column_id = m.column_id

			SELECT @sql = SUBSTRING(@sql, 1, LEN(@sql) - LEN(@CRLF) - 1) + @CRLF

			SELECT @sql = @sql + ')' + @CRLF

			SELECT @sql = @sql + 'SELECT' + @CRLF

			SELECT @sql = @sql + @TAB + '%2.[' + CASE WHEN @import > 0 THEN m.name ELSE uc.name END + '],' + @CRLF
			FROM @use_columns uc
			INNER JOIN @mapped_columns m
			ON uc.column_id = m.column_id

			SELECT @sql = SUBSTRING(@sql, 1, LEN(@sql) - LEN(@CRLF) - 1) + @CRLF

			SELECT @sql = @sql + REPLACE(@join_sql, '%0', 'FULL OUTER')

			SELECT @sql = @sql + 'WHERE '
			IF @where IS NOT NULL
				SELECT @sql = @sql + '(' + @where + ') AND (' + @CRLF

			SET @i = 0
			SELECT
				@sql = @sql +
					CASE WHEN @i = 0 THEN '      ' ELSE '  AND ' END +
					'%1.[' + CASE WHEN @import > 0 THEN kc.name ELSE m.name END + '] IS NULL' + @CRLF,
				@i = @i + 1
			FROM @key_columns kc
			INNER JOIN @mapped_columns m
			ON kc.column_id = m.column_id

			IF @where IS NOT NULL
				SELECT @sql = @sql + ')' + @CRLF

			-- do not add SQL to explicitly turn off IDENTITY_INSERT, as it loses the rowcount and is turned off automatically when we leave the scope of the EXEC() anyway

			SET @sql = REPLACE(REPLACE(REPLACE(@sql, '%0', CASE WHEN @import > 0 THEN @local_full_table_name ELSE @remote_full_table_name END), '%1', @to), '%2', @from);

			IF @show_sql = 1 PRINT @sql + @CRLF

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

			SELECT @sql = @sql + REPLACE(@join_sql, '%0', 'FULL OUTER')

			SELECT @sql = @sql + 'WHERE '
			IF @where IS NOT NULL
				SELECT @sql = @sql + '(' + @where + ') AND (' + @CRLF

			SET @i = 0
			SELECT
				@sql = @sql +
					CASE WHEN @i = 0 THEN '      ' ELSE '   OR ' END +
					'(%1.[' + CASE WHEN @import > 0 THEN kc.name ELSE m.name END + '] IS NOT NULL AND %2.[' + CASE WHEN @import > 0 THEN m.name ELSE kc.name END + '] IS NULL)' + @CRLF,
				@i = @i + 1
			FROM @key_columns kc
			INNER JOIN @mapped_columns m
			ON kc.column_id = m.column_id

			IF @where IS NOT NULL
				SELECT @sql = @sql + ')' + @CRLF

			SET @sql = REPLACE(REPLACE(@sql, '%1', @to), '%2', @from);

			IF @show_sql = 1 PRINT @sql + @CRLF

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
		IF @changed_rows = 1
		BEGIN
			RAISERROR('%s%sing changed rows...', 0, 1, @CRLF, @Upper)

			SET @sql = 'UPDATE %1' + @CRLF

			SET @i = 0
			SELECT
				@sql = @sql + @TAB + CASE WHEN @i = 0 THEN 'SET ' ELSE @TAB END + '[' + CASE WHEN @import > 0 THEN uc.name ELSE m.name END + '] = %2.[' + CASE WHEN @import > 0 THEN m.name ELSE uc.name END + '],' + @CRLF,
				@i = @i + 1
			FROM @use_columns uc
			INNER JOIN @mapped_columns m
			ON uc.column_id = m.column_id
			LEFT OUTER JOIN @identity_columns ic
			ON uc.column_id = ic.column_id
			WHERE ic.column_id IS NULL

			SELECT @sql = SUBSTRING(@sql, 1, LEN(@sql) - LEN(@CRLF) - 1) + @CRLF

			SELECT @sql = @sql + REPLACE(@join_sql, '%0', 'INNER')

			SELECT @sql = @sql + 'WHERE '
			IF @where IS NOT NULL
				SELECT @sql = @sql + '(' + @where + ') AND (' + @CRLF

			SET @i = 0
			SELECT
				@sql = @sql +
					CASE WHEN @i = 0 THEN '      ' ELSE '   OR ' END +
					'([ours].[' + uc.name + '] IS NULL AND [theirs].[' + m.name + '] IS NOT NULL)' + @CRLF +
					'   OR ([ours].[' + uc.name + '] IS NOT NULL AND [theirs].[' + m.name + '] IS NULL)' + @CRLF +
					'   OR [ours].[' + uc.name + '] <> [theirs].[' + m.name + ']' + @CRLF,
				@i = @i + 1
			FROM @use_columns uc
			INNER JOIN @mapped_columns m
			ON uc.column_id = m.column_id
			LEFT OUTER JOIN @key_columns kc
			ON uc.column_id = kc.column_id
			WHERE kc.column_id IS NULL

			IF @where IS NOT NULL
				SELECT @sql = @sql + ')' + @CRLF

			-- do not add SQL to explicitly turn off IDENTITY_INSERT, as it loses the rowcount and is turned off automatically when we leave the scope of the EXEC() anyway

			SET @sql = REPLACE(REPLACE(REPLACE(@sql, '%0', CASE WHEN @import > 0 THEN @local_full_table_name ELSE @remote_full_table_name END), '%1', @to), '%2', @from);

			IF @show_sql = 1 PRINT @sql + @CRLF

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

	IF @interleave = 1
	BEGIN
		SELECT @sql = @sql +
			@TAB + '   [ours].[' + u.name + '] AS [<<< ' + u.name + '],' + @CRLF +
			@TAB + '   [theirs].[' + m.name + '] AS [>>> ' + m.name + '],' + @CRLF
		FROM @use_columns u
		INNER JOIN @mapped_columns m
		ON u.column_id = m.column_id
	END
	ELSE
	BEGIN
		SET @sql = @sql + '''OURS <<<'' AS [ ],' + @CRLF

		SELECT @sql = @sql + @TAB + '   [ours].[' + name + '],' + @CRLF
		FROM @local_columns

		SET @sql = @sql + @TAB + '   ''THEIRS >>>'' AS [ ],' + @CRLF

		SELECT @sql = @sql + @TAB + '   [theirs].[' + name + '],' + @CRLF
		FROM @remote_columns
	END

	SELECT @sql = SUBSTRING(@sql, 1, LEN(@sql) - LEN(@CRLF) - 1) + @CRLF

	SELECT @sql = @sql + REPLACE(@join_sql, '%0', 'FULL OUTER')

	SELECT @sql = @sql + 'WHERE '
	IF @where IS NOT NULL
		SELECT @sql = @sql + '(' + @where + ') AND (' + @CRLF

	SET @i = 0
	SELECT
		@sql = @sql +
			CASE WHEN @i = 0 THEN '      ' ELSE '   OR ' END +
			'([ours].[' + kc.name + '] IS NULL AND [theirs].[' + m.name + '] IS NOT NULL)' + @CRLF +
			'   OR ([ours].[' + kc.name + '] IS NOT NULL AND [theirs].[' + m.name + '] IS NULL)' + @CRLF,
		@i = @i + 1
	FROM @key_columns kc
	INNER JOIN @mapped_columns m
	ON kc.column_id = m.column_id

	SELECT
		@sql = @sql +
			'   OR ([ours].[' + uc.name + '] IS NULL AND [theirs].[' + m.name + '] IS NOT NULL)' + @CRLF +
			'   OR ([ours].[' + uc.name + '] IS NOT NULL AND [theirs].[' + m.name + '] IS NULL)' + @CRLF +
			'   OR [ours].[' + uc.name + '] <> [theirs].[' + m.name + ']' + @CRLF
	FROM @use_columns uc
	INNER JOIN @mapped_columns m
	ON uc.column_id = m.column_id
	LEFT OUTER JOIN @key_columns kc
	ON uc.column_id = kc.column_id
	WHERE kc.column_id IS NULL

	IF @where IS NOT NULL
		SELECT @sql = @sql + ')' + @CRLF

	IF @show_sql = 1 PRINT @sql + @CRLF

	EXEC (@sql)
	SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

	IF @error <> 0 GOTO complete

	IF @rowcount > 0
		RAISERROR('Data differences found between OURS <<< %s and THEIRS >>> %s.%s - Switch to results window to view differences.%s - Call [Import|Export][AddedRows|DeletedRows|ChangedRows|All] (e.g. ImportAddedRows) with the same arguments to transfer changes.%s', 16, 1, @local_full_table_name, @remote_full_table_name, @CRLF, @CRLF, @CRLF)
	ELSE
		RAISERROR('%sNo data differences found between OURS <<< %s and THEIRS >>> %s.', 0, 1, @CRLF, @local_full_table_name, @remote_full_table_name)

complete:
END
GO
