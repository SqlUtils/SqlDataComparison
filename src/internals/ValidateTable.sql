SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[ValidateTable]
	@server SYSNAME,
	@database SYSNAME,
	@schema SYSNAME,
	@table SYSNAME,
	@database_part internals.QuotedServerPlusTableName,
	@full_table_name internals.FourPartQuotedName
AS
BEGIN
	SET NOCOUNT ON;

	-- used for building readable SQL
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	-- loop var
	DECLARE @i INT

	-- holds SQL for the current operation
	DECLARE @params NVARCHAR(MAX)
	DECLARE @sql NVARCHAR(MAX)

	-- used to collect @@ return values
	DECLARE @error INT
	DECLARE @rowcount INT

	/*
	 * Check for database existence
	 */
	SET @params =
		'@rowcount int output'
	SET @sql = 
		'SELECT @rowcount = COUNT(*)' + @CRLF +
		'FROM ' + ISNULL(QUOTENAME(@server) + '.', '') + 'master.sys.databases' + @CRLF +
		'WHERE name = ' + QUOTENAME(@database, '''')

	EXEC sp_executesql @sql, @params, @rowcount OUTPUT
	SET @error = @@ERROR

	IF @error <> 0
	BEGIN
		GOTO error
	END

	IF @rowcount <> 1
	BEGIN
		DECLARE @serverInfo NVARCHAR(MAX) = ISNULL(' on linked server ' + QUOTENAME(@server), '')
		DECLARE @databaseInfo NVARCHAR(MAX) = QUOTENAME(@database)
		RAISERROR('Cannot find database %s%s', 16, 1, @databaseInfo, @serverInfo)
		GOTO error
	END

	/*
	 * Check for table existence
	 */
	SET @params =
		'@schema sysname,' + @CRLF +
		'@table sysname,' + @CRLF +
		'@object_id int = null output'
	SET @sql =
		'SELECT @object_id = o.object_id' + @CRLF +
		'FROM ' + @database_part + '.sys.objects o' + @CRLF +
		'INNER JOIN ' + @database_part + '.sys.schemas s' + @CRLF +
		'ON o.schema_id = s.schema_id' + @CRLF +
		'AND s.name = @schema' + @CRLF +
		'WHERE o.name = @table' + @CRLF +
		'AND o.type = ''U''' + @CRLF

	EXEC sp_executesql @sql, @params, @schema, @table
	SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

	IF @error <> 0 GOTO error

	IF @rowcount = 0
	BEGIN
		RAISERROR('Cannot find table %s', 16, 1, @full_table_name)
		GOTO error
	END

	RETURN 0

error:
	RETURN -1
END
GO
