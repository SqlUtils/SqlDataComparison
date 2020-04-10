SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[CheckTheirColumnsExists]
	@use_columns internals.ColumnsTable READONLY,
	@mapped_columns internals.ColumnsTable READONLY,
	@their_columns internals.ColumnsTable READONLY,
	@their_full_table_name SYSNAME
AS
BEGIN
	SET NOCOUNT ON;

	-- used to collect SP return values
	DECLARE @retval INT

	DECLARE @mapped_use_columns internals.ColumnsTable

	INSERT INTO @mapped_use_columns (name)
	SELECT m.name
	FROM @use_columns u
	INNER JOIN @mapped_columns m
	ON u.column_id = m.column_id

	EXEC @retval = internals.ValidateColumns
		@mapped_use_columns, @their_columns,
		'[', ']', -- use [] to quote these names, as we know they exist locally
		'Required column %s does not exist in %s',
		'Required columns %s do not exist in %s',
		@their_full_table_name

	IF @retval <> 0 OR @@ERROR <> 0 GOTO error

	RETURN 0

error:
	RETURN -1
END
GO
