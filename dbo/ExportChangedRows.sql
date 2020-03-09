SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ExportChangedRows]
	@our_table_name sysname,
	@their_table_name sysname
AS
BEGIN
	SET NOCOUNT ON;

	EXEC internals.CompareAndReconcile
		@our_table_name = @our_table_name,
		@their_table_name = @their_table_name,
		@import_changed_rows = -1
END
GO
