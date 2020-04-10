SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[ProcessMapParam]
	@map nvarchar(max) = null,
	@local_columns internals.ColumnsTable READONLY,
	@remote_columns internals.ColumnsTable READONLY,
	@local_full_table_name SYSNAME,
	@remote_full_table_name SYSNAME
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
		SELECT column_id, name
		FROM @local_columns
	END
	ELSE
	BEGIN
		CREATE TABLE #column_mapping
		(
			[name] sysname,
			rename sysname
		)

		BEGIN TRY
			INSERT INTO #column_mapping
			SELECT [name], rename
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

		INSERT INTO @map_source (name)
		SELECT name
		FROM #column_mapping

		EXEC @retval = internals.ValidateColumns
			@map_source, @local_columns,
			'''', '''',
			'Source column name %s specified in @map does not exist in %s',
			'Source column names %s specified in @map do not exist in %s',
			@local_full_table_name

		IF @retval <> 0 OR @@ERROR <> 0 GOTO error

		-- validate mapping target columns
		DECLARE @map_target internals.ColumnsTable

		INSERT INTO @map_target (name)
		SELECT rename
		FROM #column_mapping

		EXEC @retval = internals.ValidateColumns
			@map_target, @remote_columns,
			'''', '''',
			'Target column name %s specified in @map does not exist in %s',
			'Target column names %s specified in @map do not exist in %s',
			@remote_full_table_name

		IF @retval <> 0 OR @@ERROR <> 0 GOTO error

		-- we already know that mapped columns do map, so we can safely convert to the canoncial remote name here
		SELECT lc.column_id, ISNULL(rc.name, lc.name)
		FROM @local_columns lc
		LEFT OUTER JOIN #column_mapping m
		ON lc.name = m.name
		LEFT OUTER JOIN @remote_columns rc
		ON m.rename = rc.name
	END

	RETURN 0

error:
	RETURN -1
END
GO
