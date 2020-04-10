SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[ProcessJoinParam]
	@join NVARCHAR(MAX),
	@use_columns internals.ColumnsTable READONLY,
	@local_full_table_name SYSNAME
AS
BEGIN
	SET NOCOUNT ON;

	-- used to collect @@ return values
	DECLARE @error INT
	DECLARE @rowcount INT

	-- used to collect SP return values
	DECLARE @retval INT

	DECLARE @join_columns internals.ColumnsTable

	INSERT INTO @join_columns (name)
	SELECT name FROM internals.SplitColumnNames(@join)
	SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

	IF @error <> 0
	BEGIN
		RAISERROR('*** Illegal or missing column names found in @join ''%s'' (quote column names using [...] if necessary)', 16, 1, @join)
		GOTO error
	END

	EXEC @retval = internals.ValidateColumns
		@join_columns, @use_columns,
		'''', '''',
		'Column name %s specified in @join does not exist in %s',
		'Column names %s specified in @join do not exist in %s',
		@local_full_table_name

	IF @retval <> 0 OR @@ERROR <> 0 GOTO error

	SELECT c.column_id, c.name
	FROM @use_columns c
	INNER JOIN @join_columns jc
	ON c.name = jc.name

	RETURN 0

error:
	RETURN -1
END
GO
