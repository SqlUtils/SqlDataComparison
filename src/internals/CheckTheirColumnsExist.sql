SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[CheckTheirColumnsExist]
	@use_columns internals.ColumnsTable READONLY,
	@mapped_columns internals.ColumnsTable READONLY,
	@their_columns internals.ColumnsTable READONLY,
	@their_full_table_name internals.FourPartQuotedName
AS
BEGIN
	SET NOCOUNT ON;

	-- used to collect SP return values
	DECLARE @retval INT

	DECLARE @mapped_use_columns internals.ColumnsTable

	INSERT INTO @mapped_use_columns (quotedName)
	SELECT m.quotedName
	FROM @use_columns uc
	INNER JOIN @mapped_columns m
	ON uc.column_id = m.column_id

	EXEC @retval = internals.ValidateColumns
		@mapped_use_columns, @their_columns,
		'', '', -- don't 'air-quote' the names in the warning in this case, as we know they exist locally
		'Required column %s does not exist in %s',
		'Required columns %s do not exist in %s',
		@their_full_table_name

	IF @retval <> 0 OR @@ERROR <> 0 GOTO error

	RETURN 0

error:
	RETURN -1
END
GO
