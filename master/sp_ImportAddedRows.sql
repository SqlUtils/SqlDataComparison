SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF EXISTS(SELECT * FROM sys.objects WHERE schema_id = 1 AND type = 'P' AND name = 'sp_ImportAddedRows')
	DROP PROCEDURE sp_ImportAddedRows
GO
CREATE PROCEDURE sp_ImportAddedRows
	@our_table_name sysname,
	@their_table_name sysname,
	@use_columns nvarchar(max) = null,
	@join_columns nvarchar(max) = null,
	@map_columns nvarchar(max) = null
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @default_db_name sysname = DB_NAME()

	EXEC SqlUtils.internals.CompareAndReconcile
		@default_db_name = @default_db_name,
		@our_table_name = @our_table_name,
		@their_table_name = @their_table_name,
		@use_columns = @use_columns,
		@join_columns = @join_columns,
		@map_columns = @map_columns,
		@import = 1,
		@added_rows = 1
END
GO
