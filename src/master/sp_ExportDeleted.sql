SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE sp_ExportDeleted
	@ourTableName NVARCHAR(1035),
	@theirTableName NVARCHAR(1035),
	@map nvarchar(max) = null,
	@join nvarchar(max) = null,
	@use nvarchar(max) = null,
	@ids nvarchar(max) = null,
	@where nvarchar(max) = null,
	@showSql bit = null,
	@interleave bit = null
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @default_db_name sysname = DB_NAME()

	EXEC SqlUtils.core.SqlDataComparison
		@default_db_name = @default_db_name,
		@ourTableName = @ourTableName,
		@theirTableName = @theirTableName,
		@map = @map,
		@join = @join,
		@use = @use,
		@ids = @ids,
		@where = @where,
		@showSql = @showSql,
		@interleave = @interleave,
		@import = -1,
		@deleted_rows = 1
END
GO
