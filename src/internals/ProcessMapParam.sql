SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[ProcessMapParam]
	@map nvarchar(max) = null,
	@our_columns internals.ColumnsTable READONLY,
	@their_columns internals.ColumnsTable READONLY,
	@our_full_table_name internals.FourPartQuotedName,
	@their_full_table_name internals.FourPartQuotedName
AS
BEGIN
	SET NOCOUNT ON;

	-- used to collect @@ return values
	DECLARE @error INT
	DECLARE @rowcount INT

	-- used to collect SP return values
	DECLARE @retval INT

	IF @map IS NULL
	BEGIN
		SELECT column_id, quoted_name
		FROM @our_columns
	END
	ELSE
	BEGIN
		DECLARE @column_mapping internals.ColumnsMap

		BEGIN TRY
			INSERT INTO @column_mapping (quoted_name, quoted_rename)
			SELECT quoted_name, quoted_rename
			FROM internals.SplitColumnMap(@map)

			SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR
		END TRY
		BEGIN CATCH
			SET @error = -1
		END CATCH

		IF @error <> 0
		BEGIN
			RAISERROR('Illegal @map parameter ''%s''; use ''our_col1, their_col1; our_col2, their_col2'' quoting column names using [...] if necessary', 16, 1, @map)
			GOTO error
		END

		-- validate mapping source columns
		DECLARE @map_source internals.ColumnsTable

		INSERT INTO @map_source (quoted_name)
		SELECT quoted_name
		FROM @column_mapping

		EXEC @retval = internals.ValidateColumns
			@map_source, @our_columns,
			'''', '''',
			'Source column name %s specified in @map does not exist in %s',
			'Source column names %s specified in @map do not exist in %s',
			@our_full_table_name

		IF @retval <> 0 OR @@ERROR <> 0 GOTO error

		-- validate mapping target columns
		DECLARE @map_target internals.ColumnsTable

		INSERT INTO @map_target (quoted_name)
		SELECT quoted_rename
		FROM @column_mapping

		EXEC @retval = internals.ValidateColumns
			@map_target, @their_columns,
			'''', '''',
			'Target column name %s specified in @map does not exist in %s',
			'Target column names %s specified in @map do not exist in %s',
			@their_full_table_name

		IF @retval <> 0 OR @@ERROR <> 0 GOTO error

		-- we already know that mapped columns do map, so we can safely convert to the canoncial remote name here
		SELECT lc.column_id, ISNULL(rc.quoted_name, lc.quoted_name) AS quoted_name
		FROM @our_columns lc
		LEFT OUTER JOIN @column_mapping m
		ON lc.quoted_name = m.quoted_name
		LEFT OUTER JOIN @their_columns rc
		ON m.quoted_rename = rc.quoted_name
	END

	RETURN 0

error:
	RETURN -1
END
GO
