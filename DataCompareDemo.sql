SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DataCompareDemo]
	@table_name sysname,
	@remote_db_name sysname,
	@import_theirs_to_ours bit = null,
	@import_ours_to_theirs bit = null,
	@schema_name sysname = 'dbo'
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)
	DECLARE @TAB CHAR(1) = CHAR(9)

	CREATE TABLE #columns (column_id int, name sysname)
	INSERT INTO #columns (column_id, name)
    SELECT c.column_id, c.name
    FROM sys.objects o
    INNER JOIN sys.schemas s
    ON o.schema_id = s.schema_id
    AND s.name = @schema_name
    INNER JOIN sys.columns c
    ON o.object_id = c.object_id
    WHERE o.name = @table_name

	CREATE TABLE #key_columns (column_id int, name sysname)
	INSERT INTO #key_columns (column_id, name)
	SELECT c.column_id, c.name
	FROM sys.objects o
	INNER JOIN sys.schemas s
	ON o.schema_id = s.schema_id
	AND s.name = @schema_name
	INNER JOIN sys.indexes i
	ON o.object_id = i.object_id
	AND i.is_primary_key = 1
	INNER JOIN sys.index_columns ic
	ON i.object_id = ic.object_id
	AND i.index_id = ic.index_id
	INNER JOIN sys.columns c
	ON c.column_id = ic.column_id
	AND c.object_id = o.object_id
	WHERE o.name = @table_name

	DECLARE @i INT

	-- local and remote table names
	DECLARE @local_table_name sysname = @schema_name + '.' + @table_name
	DECLARE @remote_table_name sysname = @remote_db_name + '.' + @schema_name + '.' + @table_name

	/*
	 * CREATE THE COMMON JOIN SQL
	 */
	DECLARE @JOIN NVARCHAR(MAX)

	SELECT @JOIN = 'FROM ' + @local_table_name + ' [ours]' + @CRLF
	SELECT @JOIN = @JOIN + 'FULL OUTER JOIN ' + @remote_table_name + ' [theirs]' + @CRLF

	SET @i = 0
	SELECT
		@JOIN = @JOIN + CASE WHEN @i = 0 THEN 'ON' ELSE 'AND' END + ' [ours].[' + #key_columns.name + '] = [theirs].[' + #key_columns.name + ']' + @CRLF,
		@i = @i + 1
	FROM #key_columns

	-- Holds SQL for the current operation
	DECLARE @SQL NVARCHAR(MAX)

	DECLARE @error INT
	DECLARE @rowcount INT

	/*
	 * THEIRS TO OURS AND OURS TO THEIRS
	 */
	IF @import_theirs_to_ours = 1 OR @import_ours_to_theirs = 1
	BEGIN
		DECLARE @HasIdentity BIT = 0

		SELECT @HasIdentity = 1
		FROM sys.objects o
		INNER JOIN sys.identity_columns ic
		ON o.object_id = ic.object_id
		WHERE o.name = @table_name

		SET @SQL = CASE WHEN @HasIdentity = 1 THEN 'SET IDENTITY_INSERT %0 ON;' + @CRLF + @CRLF ELSE '' END

		SET @SQL = @SQL + 'INSERT INTO %0 (' + @CRLF

		SELECT @SQL = @SQL + @TAB + '[' + #columns.name + '],' + @CRLF
		FROM #columns

		SELECT @SQL = SUBSTRING(@SQL, 1, LEN(@SQL) - LEN(@CRLF) - 1) + @CRLF

		SELECT @SQL = @SQL + ')' + @CRLF

		SELECT @SQL = @SQL + 'SELECT' + @CRLF

		SELECT @SQL = @SQL + @TAB + '%1.[' + #columns.name + '],' + @CRLF
		FROM #columns

		SELECT @SQL = SUBSTRING(@SQL, 1, LEN(@SQL) - LEN(@CRLF) - 1) + @CRLF

		SELECT @SQL = @SQL + @JOIN

		SET @i = 0
		SELECT
			@SQL = @SQL +
				CASE WHEN @i = 0 THEN 'WHERE ' ELSE '  AND ' END +
				'%2.[' + #key_columns.name + '] IS NULL' + @CRLF,
			@i = @i + 1
		FROM #key_columns

		-- don't explicitly turn off IDENTITY_INSERT as it loses the rowcount and is
		-- turned off automatically when we leave the scope of the EXEC()

		DECLARE @IMPORT_SQL NVARCHAR(MAX)

		IF @import_theirs_to_ours = 1
		BEGIN
			SET @IMPORT_SQL = REPLACE(REPLACE(REPLACE(@SQL, '%0', @local_table_name), '%1', '[theirs]'), '%2', '[ours]');

			SET NOCOUNT OFF;
			EXEC (@IMPORT_SQL)
			SELECT @error = @@ERROR, @rowcount = @@ROWCOUNT
			SET NOCOUNT ON;

			IF @error = 0
				RAISERROR('Requested import completed with no errors. Transferred %d rows from theirs into ours.', 0, 1, @rowcount)
		END

		IF @import_ours_to_theirs = 1
		BEGIN
			SET @IMPORT_SQL = REPLACE(REPLACE(REPLACE(@SQL, '%0', @remote_table_name), '%1', '[ours]'), '%2', '[theirs]');

			SET NOCOUNT OFF;
			EXEC (@IMPORT_SQL)
			SELECT @error = @@ERROR, @rowcount = @@ROWCOUNT
			SET NOCOUNT ON;

			IF @error = 0
				RAISERROR('Requested import completed with no errors. Transferred %d rows from ours into theirs.', 0, 1, @rowcount)
		END
	END

	/*
	 * DISPLAY THE DIFFERENCES
	 */

	SET @SQL = 'SELECT '

	SET @SQL = @SQL + '''OURS >>>'' AS [ ],' + @CRLF
	SELECT @SQL = @SQL + @TAB + '   [ours].[' + #columns.name + '],' + @CRLF
	FROM #columns

	SET @SQL = @SQL + @TAB + '   ''THEIRS >>>'' AS [ ],' + @CRLF
	SELECT @SQL = @SQL + @TAB + '   [theirs].[' + #columns.name + '],' + @CRLF
	FROM #columns

	SELECT @SQL = SUBSTRING(@SQL, 1, LEN(@SQL) - LEN(@CRLF) - 1) + @CRLF

	SELECT @SQL = @SQL + @JOIN

	SET @i = 0
	SELECT
		@SQL = @SQL +
			CASE WHEN @i = 0 THEN 'WHERE ' ELSE '   OR ' END +
			'[ours].[' + #key_columns.name + '] IS NULL AND [theirs].[' + #key_columns.name + '] IS NOT NULL' + @CRLF +
			'   OR [ours].[' + #key_columns.name + '] IS NOT NULL AND [theirs].[' + #key_columns.name + '] IS NULL' + @CRLF,
		@i = @i + 1
	FROM #key_columns

	SELECT
		@SQL = @SQL +
			'   OR [ours].[' + #columns.name + '] IS NULL AND [theirs].[' + #columns.name + '] IS NOT NULL' + @CRLF +
			'   OR [ours].[' + #columns.name + '] IS NOT NULL AND [theirs].[' + #columns.name + '] IS NULL' + @CRLF +
			'   OR [ours].[' + #columns.name + '] <> [theirs].[' + #columns.name + ']' + @CRLF,
		@i = @i + 1
	FROM #columns
	LEFT OUTER JOIN #key_columns
	ON #columns.column_id = #key_columns.column_id
	WHERE #key_columns.column_id IS NULL

	EXEC (@SQL)

	IF @@ROWCOUNT > 0
		RAISERROR('Data differences found between OURS >>> %s and THEIRS >>> %s.%sSwitch to results window to view differences.%s - Call again with @import_theirs_to_ours or @import_ours_to_theirs set to transfer changes.%s - Differences in rows which are in both need to be resolved by hand.', 16, 1, @local_table_name, @remote_table_name, @CRLF, @CRLF, @CRLF)
	ELSE
		RAISERROR('No data differences found between OURS >>> %s and THEIRS >>> %s.', 0, 1, @local_table_name, @remote_table_name)

complete:
END