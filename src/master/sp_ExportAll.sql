SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE sp_ExportAll
	@ourTableName sysname,
	@theirTableName sysname,
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

	DECLARE @defaultDbName sysname = DB_NAME()

	EXEC SqlUtils.core.SqlDataComparison
		@defaultDbName = @defaultDbName,
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
		@added_rows = 1,
		@deleted_rows = 1,
		@changed_rows = 1
END
GO
