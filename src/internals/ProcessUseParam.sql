SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[ProcessUseParam]
	@use NVARCHAR(MAX),
	@our_columns internals.ColumnsTable READONLY,
	@our_full_table_name internals.FourPartQuotedName
AS
BEGIN
	SET NOCOUNT ON;

	-- used to collect @@ return values
	DECLARE @error INT
	DECLARE @rowcount INT

	-- used to collect SP return values
	DECLARE @retval INT

	IF @use IS NULL
	BEGIN
		SELECT column_id, quoted_name
		FROM @our_columns
	END
	ELSE
	BEGIN
		DECLARE @use_columns internals.ColumnsTable

		INSERT INTO @use_columns (quoted_name)
		SELECT quoted_name FROM internals.SplitColumnNames(@use)
		SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR

		IF @error <> 0
		BEGIN
			RAISERROR('*** Illegal or missing column names found in @use ''%s'' (quote column names using [...] if necessary)', 16, 1, @use)
			GOTO error
		END

		EXEC @retval = internals.ValidateColumns
			@use_columns, @our_columns,
			'''', '''', 
			'Column name %s specified in @use does not exist in %s',
			'Column names %s specified in @use do not exist in %s',
			@our_full_table_name

		IF @retval <> 0 OR @@ERROR <> 0 GOTO error

		-- fill out @use_columns and give canonical name
		UPDATE uc
		SET column_id = c.column_id, quoted_name = c.quoted_name
		FROM @use_columns uc
		INNER JOIN @our_columns c
		ON uc.quoted_name = c.quoted_name

		SELECT column_id, quoted_name
		FROM @use_columns
	END

	RETURN 0

error:
	RETURN -1
END
GO
