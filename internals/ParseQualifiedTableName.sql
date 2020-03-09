SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [internals].[ParseQualifiedTableName]
	@qualified_table_name sysname,
	@server sysname OUTPUT,
	@database sysname OUTPUT,
	@schema sysname OUTPUT,
	@table sysname OUTPUT,
	@full_database_part sysname OUTPUT,
	@full_table_name sysname OUTPUT,
	@param_name sysname = ''
AS
BEGIN
	SET NOCOUNT ON;
	SELECT
		@server = PARSENAME(@qualified_table_name, 4),
		@database = PARSENAME(@qualified_table_name, 3),
		@schema = ISNULL(PARSENAME(@qualified_table_name, 2), 'dbo'),
		@table = PARSENAME(@qualified_table_name, 1)

	IF @table IS NULL
	BEGIN
		RAISERROR('Invalid table name in parameter %s=''%s''', 16, 1, @param_name, @qualified_table_name)
		GOTO completed
	END

	IF @database IS NULL
	BEGIN
		RAISERROR('Invalid database name in parameter %s=''%s''', 16, 1, @param_name, @qualified_table_name)
		GOTO completed
	END

	SET @full_database_part = ISNULL('[' + @server + '].[', '[') + @database + ']'
	SET @full_table_name = @full_database_part + '.[' + @schema + '].[' + @table + ']'

completed:
END