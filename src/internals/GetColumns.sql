SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[GetColumns]
	@database_part SYSNAME,
	@schema SYSNAME,
	@table SYSNAME,
	@full_table_name SYSNAME
AS
BEGIN
	SET NOCOUNT ON;

	-- used for building readable SQL
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	-- holds SQL for the current operation
	DECLARE @params NVARCHAR(MAX)
	DECLARE @sql NVARCHAR(MAX)

	-- used to collect @@ return values
	DECLARE @error INT
	DECLARE @rowcount INT

	/*
	 * Get local table columns
	 */
	SET @params =
		'@schema sysname,' + @CRLF +
		'@table sysname'
	SET @sql =
		'SELECT c.column_id, c.name' + @CRLF +
		'FROM ' + @database_part + '.sys.objects o' + @CRLF +
		'INNER JOIN ' + @database_part + '.sys.schemas s' + @CRLF +
		'ON o.schema_id = s.schema_id' + @CRLF +
		'AND s.name = @schema' + @CRLF +
		'INNER JOIN ' + @database_part + '.sys.columns c' + @CRLF +
		'ON o.object_id = c.object_id' + @CRLF +
		'WHERE o.name = @table'
		
	EXEC sp_executesql @sql, @params, @schema, @table
	SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

	IF @error <> 0 GOTO error

	IF @rowcount = 0
	BEGIN
		RAISERROR('There are no columns for table %s', 16, 1, @full_table_name)
		GOTO error
	END

	RETURN 0

error:
	RETURN -1
END
GO
