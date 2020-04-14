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
		SELECT column_id, quotedName
		FROM @our_columns
	END
	ELSE
	BEGIN
		CREATE TABLE #column_mapping
		(
			quotedName internals.QuotedName,
			quotedRename internals.QuotedName
		)

		BEGIN TRY
			INSERT INTO #column_mapping (quotedName, quotedRename)
			SELECT QUOTENAME([name]) AS quotedName, QUOTENAME(rename) AS quotedRename
			FROM internals.SplitColumnMap(@map)

			SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR
		END TRY
		BEGIN CATCH
			SET @error = -1
		END CATCH

		IF @error <> 0
		BEGIN
		  -- names passed to @map param should NOT be quoted, and (as currently coded) cannot contain , or ;
			RAISERROR('Illegal @map parameter ''%s''; use ''our_col1, their_col1; our_col2, their_col2''', 16, 1, @map)
			GOTO error
		END

		-- validate mapping source columns
		DECLARE @map_source internals.ColumnsTable

		INSERT INTO @map_source (quotedName)
		SELECT quotedName
		FROM #column_mapping

		EXEC @retval = internals.ValidateColumns
			@map_source, @our_columns,
			'''', '''',
			'Source column name %s specified in @map does not exist in %s',
			'Source column names %s specified in @map do not exist in %s',
			@our_full_table_name

		IF @retval <> 0 OR @@ERROR <> 0 GOTO error

		-- validate mapping target columns
		DECLARE @map_target internals.ColumnsTable

		INSERT INTO @map_target (quotedName)
		SELECT quotedRename
		FROM #column_mapping

		EXEC @retval = internals.ValidateColumns
			@map_target, @their_columns,
			'''', '''',
			'Target column name %s specified in @map does not exist in %s',
			'Target column names %s specified in @map do not exist in %s',
			@their_full_table_name

		IF @retval <> 0 OR @@ERROR <> 0 GOTO error

		-- we already know that mapped columns do map, so we can safely convert to the canoncial remote name here
		SELECT lc.column_id, ISNULL(rc.quotedName, lc.quotedName) AS quotedName
		FROM @our_columns lc
		LEFT OUTER JOIN #column_mapping m
		ON lc.quotedName = m.quotedName
		LEFT OUTER JOIN @their_columns rc
		ON m.rename = rc.quotedName
	END

	RETURN 0

error:
	RETURN -1
END
GO
