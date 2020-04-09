SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [dbo].[ExportChanged]
	@our_table_name sysname,
	@their_table_name sysname,
	@map nvarchar(max) = null,
	@join nvarchar(max) = null,
	@use nvarchar(max) = null,
	@where nvarchar(max) = null,
	@show_sql bit = null,
	@interleave bit = null
AS
BEGIN
	SET NOCOUNT ON;

	EXEC core.SqlDataComparison
		@our_table_name = @our_table_name,
		@their_table_name = @their_table_name,
		@map = @map,
		@join = @join,
		@use = @use,
		@where = @where,
		@show_sql = @show_sql,
		@interleave = @interleave,
		@import = -1,
		@changed_rows = 1
END
GO
