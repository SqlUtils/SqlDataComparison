SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[GetIdentityColumns]
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
		'SELECT c.column_id, QUOTENAME(c.name) AS quoted_name' + @CRLF +
		'FROM ' + @database_part + '.sys.schemas s' + @CRLF +
		'INNER JOIN ' + @database_part + '.sys.objects o' + @CRLF +
		'ON o.schema_id = s.schema_id' + @CRLF +
		'INNER JOIN ' + @database_part + '.sys.columns c' + @CRLF +
		'ON c.object_id = o.object_id' + @CRLF +
		'INNER JOIN ' + @database_part + '.sys.identity_columns ic' + @CRLF +
		'ON ic.object_id = o.object_id' + @CRLF +
		'AND ic.column_id = c.column_id' + @CRLF +
		'WHERE s.name = @schema' + @CRLF +
		'AND o.name = @table'

	EXEC sp_executesql @sql, @params, @schema, @table

	IF @@ERROR <> 0 GOTO error

	RETURN 0

error:
	RETURN -1
END
GO
