SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[GetPrimaryKeyColumns]
	@database_part internals.QuotedServerPlusTableName,
	@schema SYSNAME,
	@table SYSNAME
AS
BEGIN
	SET NOCOUNT ON;

	-- used for building readable SQL
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	-- holds SQL for the current operation
	DECLARE @params NVARCHAR(MAX)
	DECLARE @sql NVARCHAR(MAX)

	SET @params =
		'@schema sysname,' + @CRLF +
		'@table sysname'
	SET @sql =
		'SELECT c.column_id, QUOTENAME(c.name) as quoted_name' + @CRLF +
		'FROM ' + @database_part + '.sys.objects o' + @CRLF +
		'INNER JOIN ' + @database_part + '.sys.schemas s' + @CRLF +
		'ON o.schema_id = s.schema_id' + @CRLF +
		'AND s.name = @schema' + @CRLF +
		'INNER JOIN ' + @database_part + '.sys.indexes i' + @CRLF +
		'ON o.object_id = i.object_id' + @CRLF +
		'AND i.is_primary_key = 1' + @CRLF +
		'INNER JOIN ' + @database_part + '.sys.index_columns ic' + @CRLF +
		'ON i.object_id = ic.object_id' + @CRLF +
		'AND i.index_id = ic.index_id' + @CRLF +
		'INNER JOIN ' + @database_part + '.sys.columns c' + @CRLF +
		'ON c.column_id = ic.column_id' + @CRLF +
		'AND c.object_id = o.object_id' + @CRLF +
		'WHERE o.name = @table'
		
	EXEC sp_executesql @sql, @params, @schema, @table

	IF @@ERROR <> 0 GOTO error

	RETURN 0

error:
	RETURN -1
END
GO
