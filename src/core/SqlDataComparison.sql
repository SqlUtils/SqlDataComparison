SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [core].[SqlDataComparison]
	@ourTableName sysname,
	@theirTableName sysname,
	@defaultDbName sysname = null,
	@map nvarchar(max) = null,
	@join nvarchar(max) = null,
	@use nvarchar(max) = null,
	@ids nvarchar(max) = null,
	@where nvarchar(max) = null,
	@import int = null, -- > 0 means import; < 0 means export
	@added_rows bit = null,
	@deleted_rows bit = null,
	@changed_rows bit = null,
	@showSql bit = null,
	@interleave bit = null
AS
BEGIN
	SET NOCOUNT ON;

	-- used for building readable SQL
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)
	DECLARE @TAB CHAR(1) = CHAR(9)

	-- loop var
	DECLARE @i INT

	-- holds SQL for the current operation
	DECLARE @params NVARCHAR(MAX)
	DECLARE @sql NVARCHAR(MAX)

	-- used to collect @@ return values
	DECLARE @error INT
	DECLARE @rowcount INT

	-- used to collect SP return values
	DECLARE @retval INT

	/*
	 * confirm @where param is approximately valid
	 */
	EXEC @retval = internals.ValidateWhereParam @where

	IF @retval <> 0 OR @@ERROR <> 0 GOTO error

	/*
	 * parse @ourTableName
	 */
	DECLARE @our_server sysname
	DECLARE @our_database sysname
	DECLARE @our_schema sysname
	DECLARE @our_table sysname
	DECLARE @our_database_part sysname
	DECLARE @our_full_table_name sysname

	EXEC @retval = internals.ValidateQualifiedTableName
		@qualified_table_name = @ourTableName,
		@defaultDbName = @defaultDbName,
		@server = @our_server OUTPUT,
		@database = @our_database OUTPUT,
		@schema = @our_schema OUTPUT,
		@table = @our_table OUTPUT,
		@full_database_part = @our_database_part OUTPUT,
		@full_table_name = @our_full_table_name OUTPUT,
		@param_name = '@ourTableName'

	IF @retval <> 0 OR @@ERROR <> 0 GOTO error

	/*
	 * parse @theirTableName
	 */
	DECLARE @their_server sysname
	DECLARE @their_database sysname
	DECLARE @their_schema sysname
	DECLARE @their_table sysname
	DECLARE @their_database_part sysname
	DECLARE @their_full_table_name sysname

	-- do not apply default database name to theirs (it becomes more confusing than helpful when user sends db.table instead of db..table by mistake)
	EXEC @retval = internals.ValidateQualifiedTableName
		@qualified_table_name = @theirTableName,
		@server = @their_server OUTPUT,
		@database = @their_database OUTPUT,
		@schema = @their_schema OUTPUT,
		@table = @their_table OUTPUT,
		@full_database_part = @their_database_part OUTPUT,
		@full_table_name = @their_full_table_name OUTPUT,
		@param_name = '@theirTableName'

	IF @retval <> 0 OR @@ERROR <> 0 GOTO error

	/*
	 * Load local columns
	 */
	DECLARE @our_columns internals.ColumnsTable

	INSERT INTO @our_columns (column_id, name)
	EXEC @retval = internals.ValidateTableAndLoadColumnNames
		@database_part = @our_database_part,
		@schema = @our_schema,
		@table = @our_table,
		@full_table_name = @our_full_table_name

	IF @retval <> -0 OR @@ERROR <> 0 GOTO error

	/*
	 * Process @use param
	 */
	DECLARE @use_columns internals.ColumnsTable

	INSERT INTO @use_columns (column_id, name)
	EXEC @retval = internals.ProcessUseParam
		@use = @use,
		@our_columns = @our_columns,
		@our_full_table_name = @our_full_table_name

	IF @retval <> 0 OR @@ERROR <> 0 GOTO error

	/*
	 * Load remote columns
	 */
	DECLARE @their_columns internals.ColumnsTable

	INSERT INTO @their_columns (column_id, name)
	EXEC @retval = internals.ValidateTableAndLoadColumnNames
		@database_part = @their_database_part,
		@schema = @their_schema,
		@table = @their_table,
		@full_table_name = @their_full_table_name

	IF @retval <> 0 OR @@ERROR <> 0 GOTO error

	/*
	 * Process column name remapping
	 */
	-- NB @mapped_columns contains local column id with mapped remote column name
	DECLARE @mapped_columns internals.ColumnsTable

	INSERT INTO @mapped_columns (column_id, name)
	EXEC @retval = internals.ProcessMapParam
		@map = @map,
		@our_columns = @our_columns,
		@their_columns = @their_columns,
		@our_full_table_name = @our_full_table_name,
		@their_full_table_name = @their_full_table_name

	IF @retval <> 0 OR @@ERROR <> 0 GOTO error

	/*
	 * Confirm that all columns to be used exist remotely
	 */
	EXEC @retval = internals.CheckTheirColumnsExist
		@use_columns = @use_columns,
		@mapped_columns = @mapped_columns,
		@their_columns  = @their_columns,
		@their_full_table_name = @their_full_table_name

	IF @retval <> 0 OR @@ERROR <> 0 GOTO error

	/*
	 * Holds table primary key columns or user-specified join columns
	 */
	DECLARE @key_columns internals.ColumnsTable

	IF @join IS NOT NULL
	BEGIN
		/*
		 * Use @join for join instead of table primary keys, if provided
		 */
		INSERT INTO @key_columns (column_id, name)
		EXEC @retval = internals.ProcessJoinParam
			@join = @join,
			@use_columns = @use_columns,
			@our_full_table_name = @our_full_table_name

		IF @retval <> 0 OR @@ERROR <> 0 GOTO error
	END
	ELSE
	BEGIN
		/*
		 * Load our table primary key columns
		 */
		INSERT INTO @key_columns (column_id, name)
		EXEC @retval = internals.GetPrimaryKeyColumns
			@database_part = @our_database_part,
			@schema = @our_schema,
			@table = @our_table

		SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

		IF @retval <> 0 OR @error <> 0 GOTO error

		IF @rowcount = 0
		BEGIN
			RAISERROR('There are no primary keys for table %s. One or more primary keys or a @join parameter are required to join the tables to be compared.', 16, 1, @our_full_table_name)
			GOTO error
		END
	END

	/*
	 * Confirm that the @ids param is valid, and convert to a where statement if it is
	 */
	DECLARE @idsWhere NVARCHAR(MAX)

	EXEC @retval = internals.ProcessIdsParam
		@ids = @ids,
		@idsWhere = @idsWhere OUTPUT,
		@key_columns = @key_columns

	IF @retval <> 0 OR @@ERROR <> 0 GOTO error

	/*
	 * CREATE THE COMMON JOIN SQL
	 */
	DECLARE @join_sql NVARCHAR(MAX)

	SELECT @join_sql = 'FROM ' + @our_full_table_name + ' [ours]' + @CRLF
	SELECT @join_sql = @join_sql + '%0 JOIN ' + @their_full_table_name + ' [theirs]' + @CRLF

	SET @i = 0
	SELECT
		@join_sql = @join_sql + CASE WHEN @i = 0 THEN 'ON' ELSE 'AND' END + ' [ours].[' + kc.name + '] = [theirs].[' + m.name + ']' + @CRLF,
		@i = @i + 1
	FROM @key_columns kc
	INNER JOIN @mapped_columns m
	ON kc.column_id = m.column_id

	/*
	 * THEIRS TO OURS AND OURS TO THEIRS
	 */
	IF @import <> 0
	BEGIN
		-- determine whether there is an identity column (must check this on the target side side of the data transfer)
		DECLARE @has_identity BIT = 0

		-- we use a standard shape table, but there can only be one identity column
		DECLARE @identity_columns internals.ColumnsTable

		-- only need to work with identity columns for adds and changes, not deletes
		IF @added_rows = 1 OR @changed_rows = 1
		BEGIN
			IF @import > 0
				INSERT INTO @identity_columns (column_id, name)
				EXEC @retval = internals.GetIdentityColumns
					@database_part = @our_database_part,
					@schema = @our_schema,
					@table = @our_table
			ELSE
				INSERT INTO @identity_columns (column_id, name)
				EXEC @retval = internals.GetIdentityColumns
					@database_part = @their_database_part,
					@schema = @their_schema,
					@table = @their_table

			SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

			IF @retval <> 0 OR @error <> 0 GOTO error
			
			IF @rowcount > 0 SET @has_identity = 1
		END

		DECLARE @actionToLower NVARCHAR(MAX) = CASE WHEN @import > 0 THEN 'import' ELSE 'export' END
		DECLARE @actionToUpper NVARCHAR(MAX) = CASE WHEN @import > 0 THEN 'Import' ELSE 'Export' END
		DECLARE @from sysname = CASE WHEN @import > 0 THEN '[theirs]' ELSE '[ours]' END
		DECLARE @to sysname = CASE WHEN @import > 0 THEN '[ours]' ELSE '[theirs]' END

		/*
		 * ADDED ROWS
		 */
		IF @added_rows = 1
		BEGIN
			RAISERROR('%s%sing added rows...', 0, 1, @CRLF, @actionToUpper)

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

			SELECT @sql = @sql + 'WHERE (' + @CRLF
			IF @idsWhere IS NOT NULL
				SELECT @sql = @sql + '      ' + @idsWhere + @CRLF + ') AND (' + @CRLF
			IF @where IS NOT NULL
				SELECT @sql = @sql + '      ' + @where + @CRLF + ') AND (' + @CRLF

			SET @i = 0
			SELECT
				@sql = @sql +
					CASE WHEN @i = 0 THEN '      ' ELSE '  AND ' END +
					'%1.[' + CASE WHEN @import > 0 THEN kc.name ELSE m.name END + '] IS NULL' + @CRLF,
				@i = @i + 1
			FROM @key_columns kc
			INNER JOIN @mapped_columns m
			ON kc.column_id = m.column_id

			SELECT @sql = @sql + ')' + @CRLF

			-- do not add SQL to explicitly turn off IDENTITY_INSERT, as it loses the rowcount and is turned off automatically when we leave the scope of the EXEC() anyway

			SET @sql = REPLACE(REPLACE(REPLACE(@sql, '%0', CASE WHEN @import > 0 THEN @our_full_table_name ELSE @their_full_table_name END), '%1', @to), '%2', @from);

			IF @showSql = 1 PRINT @sql + @CRLF

			SET NOCOUNT OFF;
			EXEC (@sql)
			SELECT @error = @@ERROR, @rowcount = @@ROWCOUNT
			SET NOCOUNT ON;

			IF @error = 0
				RAISERROR('Requested %s completed with no errors. Transferred %d rows from %s into %s.', 0, 1, @actionToLower, @rowcount, @from, @to)
		END

		/*
		 * DELETED ROWS
		 */
		IF @deleted_rows = 1
		BEGIN
			RAISERROR('%s%sing deleted rows...', 0, 1, @CRLF, @actionToUpper)

			SET @sql = 'DELETE %1' + @CRLF

			SELECT @sql = @sql + REPLACE(@join_sql, '%0', 'FULL OUTER')

			SELECT @sql = @sql + 'WHERE (' + @CRLF
			IF @idsWhere IS NOT NULL
				SELECT @sql = @sql + '      ' + @idsWhere + @CRLF + ') AND (' + @CRLF
			IF @where IS NOT NULL
				SELECT @sql = @sql + '      ' + @where + @CRLF + ') AND (' + @CRLF

			SET @i = 0
			SELECT
				@sql = @sql +
					CASE WHEN @i = 0 THEN '      ' ELSE '   OR ' END +
					'(%1.[' + CASE WHEN @import > 0 THEN kc.name ELSE m.name END + '] IS NOT NULL AND %2.[' + CASE WHEN @import > 0 THEN m.name ELSE kc.name END + '] IS NULL)' + @CRLF,
				@i = @i + 1
			FROM @key_columns kc
			INNER JOIN @mapped_columns m
			ON kc.column_id = m.column_id

			SELECT @sql = @sql + ')' + @CRLF

			SET @sql = REPLACE(REPLACE(@sql, '%1', @to), '%2', @from);

			IF @showSql = 1 PRINT @sql + @CRLF

			SET NOCOUNT OFF;
			EXEC (@sql)
			SELECT @error = @@ERROR, @rowcount = @@ROWCOUNT
			SET NOCOUNT ON;

			IF @error = 0
				RAISERROR('Requested %s completed with no errors. Deleted %d rows from %s.', 0, 1, @actionToLower, @rowcount, @to)
		END

		/*
		 * CHANGED ROWS
		 */
		IF @changed_rows = 1
		BEGIN
			RAISERROR('%s%sing changed rows...', 0, 1, @CRLF, @actionToUpper)

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

			SELECT @sql = @sql + 'WHERE (' + @CRLF
			IF @idsWhere IS NOT NULL
				SELECT @sql = @sql + '      ' + @idsWhere + @CRLF + ') AND (' + @CRLF
			IF @where IS NOT NULL
				SELECT @sql = @sql + '      ' + @where + @CRLF + ') AND (' + @CRLF

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

			-- If all columns are key columns we need a dummy condition here
			IF @@ROWCOUNT = 0 SET @SQL = @SQL + '      0 = 1 -- no non-join columns, no changes to transfer' + @CRLF

			SELECT @sql = @sql + ')' + @CRLF

			-- do not add SQL to explicitly turn off IDENTITY_INSERT, as it loses the rowcount and is turned off automatically when we leave the scope of the EXEC() anyway

			SET @sql = REPLACE(REPLACE(REPLACE(@sql, '%0', CASE WHEN @import > 0 THEN @our_full_table_name ELSE @their_full_table_name END), '%1', @to), '%2', @from);

			IF @showSql = 1 PRINT @sql + @CRLF

			SET NOCOUNT OFF;
			EXEC (@sql)
			SELECT @error = @@ERROR, @rowcount = @@ROWCOUNT
			SET NOCOUNT ON;

			IF @error = 0
				RAISERROR('Requested %s completed with no errors. Updated %d rows in %s with data from %s.', 0, 1, @actionToLower, @rowcount, @to, @from)
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
		FROM @our_columns

		SET @sql = @sql + @TAB + '   ''THEIRS >>>'' AS [ ],' + @CRLF

		SELECT @sql = @sql + @TAB + '   [theirs].[' + name + '],' + @CRLF
		FROM @their_columns
	END

	SELECT @sql = SUBSTRING(@sql, 1, LEN(@sql) - LEN(@CRLF) - 1) + @CRLF

	SELECT @sql = @sql + REPLACE(@join_sql, '%0', 'FULL OUTER')

	SELECT @sql = @sql + 'WHERE (' + @CRLF
	IF @idsWhere IS NOT NULL
		SELECT @sql = @sql + '      ' + @idsWhere + @CRLF + ') AND (' + @CRLF
	IF @where IS NOT NULL
		SELECT @sql = @sql + '      ' + @where + @CRLF + ') AND (' + @CRLF

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

	SELECT @sql = @sql + ')' + @CRLF

	IF @showSql = 1 PRINT @sql + @CRLF

	EXEC (@sql)
	SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

	IF @error <> 0 GOTO error

	IF @rowcount > 0
		RAISERROR('Data differences found between OURS <<< %s and THEIRS >>> %s.%s - Switch to results window to view differences.%s - Call [Import|Export][Added|Deleted|Changed|All] (e.g. ImportAdded) with the same arguments to transfer changes.%s', 16, 1, @our_full_table_name, @their_full_table_name, @CRLF, @CRLF, @CRLF)
	ELSE
		RAISERROR('%sNo data differences found between OURS <<< %s and THEIRS >>> %s.', 0, 1, @CRLF, @our_full_table_name, @their_full_table_name)

	RETURN 0

error:
	RETURN -1
END
GO
