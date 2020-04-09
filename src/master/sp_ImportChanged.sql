SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE sp_ImportChanged
	@our_table_name sysname,
	@their_table_name sysname,
	@map nvarchar(max) = null,
	@join nvarchar(max) = null,
	@use nvarchar(max) = null,
	@ids nvarchar(max) = null,
	@where nvarchar(max) = null,
	@show_sql bit = null,
	@interleave bit = null
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @default_db_name sysname = DB_NAME()

	EXEC SqlUtils.core.SqlDataComparison
		@default_db_name = @default_db_name,
		@our_table_name = @our_table_name,
		@their_table_name = @their_table_name,
		@map = @map,
		@join = @join,
		@use = @use,
		@ids = @ids,
		@where = @where,
		@show_sql = @show_sql,
		@interleave = @interleave,
		@import = 1,
		@changed_rows = 1
END
GO
