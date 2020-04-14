SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[ProcessJoinParam]
	@join NVARCHAR(MAX),
	@use_columns internals.ColumnsTable READONLY,
	@our_full_table_name internals.FourPartQuotedName
AS
BEGIN
	SET NOCOUNT ON;

	-- used to collect @@ return values
	DECLARE @error INT
	DECLARE @rowcount INT

	-- used to collect SP return values
	DECLARE @retval INT

	DECLARE @join_columns internals.ColumnsTable

	INSERT INTO @join_columns (quotedName)
	SELECT QUOTENAME(name) FROM internals.SplitColumnNames(@join)
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
		@our_full_table_name

	IF @retval <> 0 OR @@ERROR <> 0 GOTO error

	SELECT uc.column_id, uc.quotedName
	FROM @use_columns uc
	INNER JOIN @join_columns jc
	ON uc.quotedName = jc.quotedName

	RETURN 0

error:
	RETURN -1
END
GO
