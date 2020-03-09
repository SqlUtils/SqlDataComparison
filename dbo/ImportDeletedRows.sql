SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ImportDeletedRows]
	@our_table_name sysname,
	@their_table_name sysname,
	@use_columns nvarchar(max) = null,
	@join_columns nvarchar(max) = null,
	@map_columns nvarchar(max) = null
AS
BEGIN
	SET NOCOUNT ON;

	EXEC internals.CompareAndReconcile
		@our_table_name = @our_table_name,
		@their_table_name = @their_table_name,
		@use_columns = @use_columns,
		@join_columns = @join_columns,
		@map_columns = @map_columns,
		@import = 1,
		@deleted_rows = 1
END
GO
