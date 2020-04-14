SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[ValidateQualifiedTableName]
	@qualified_table_name internals.FourPartQuotedName,
	@default_db_name sysname = NULL,
	@server sysname OUTPUT,
	@database sysname OUTPUT,
	@schema sysname OUTPUT,
	@table sysname OUTPUT,
	@full_database_part internals.QuotedServerPlusTableName OUTPUT,
	@full_table_name internals.FourPartQuotedName OUTPUT,
	@param_name sysname = ''
AS
BEGIN
	SET NOCOUNT ON;
	SELECT
		@server = PARSENAME(@qualified_table_name, 4),
		@database = ISNULL(PARSENAME(@qualified_table_name, 3), CASE WHEN @server IS NOT NULL THEN NULL ELSE @default_db_name END),
		@schema = ISNULL(PARSENAME(@qualified_table_name, 2), 'dbo'),
		@table = PARSENAME(@qualified_table_name, 1)

	IF @table IS NULL
	BEGIN
		RAISERROR('Invalid or missing table name in parameter %s = ''%s''', 16, 1, @param_name, @qualified_table_name)
		GOTO error
	END

	IF @database IS NULL
	BEGIN
		RAISERROR('Invalid or missing database name in parameter %s = ''%s''', 16, 1, @param_name, @qualified_table_name)
		GOTO error
	END

	SET @full_database_part = ISNULL(QUOTENAME(@server) + '.', '') + QUOTENAME(@database)
	SET @full_table_name = @full_database_part + '.' + QUOTENAME(@schema) + '.' + QUOTENAME(@table)

	RETURN 0

error:
	RETURN -1
END
GO
