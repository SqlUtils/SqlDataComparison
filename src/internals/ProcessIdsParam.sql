SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[ProcessIdsParam]
	@ids NVARCHAR(MAX),
	@idsWhere NVARCHAR(MAX) OUTPUT,
	@key_columns internals.ColumnsTable READONLY,
	@mapped_columns internals.ColumnsTable READONLY
AS
BEGIN
	SET NOCOUNT ON;

	-- loop var
	DECLARE @i INT

	-- used to collect @@ return values
	DECLARE @error INT
	DECLARE @rowcount INT

	IF @ids IS NOT NULL
	BEGIN
		IF (SELECT COUNT(*) FROM @key_columns) <> 1
		BEGIN
			RAISERROR('@ids parameter cannot be used when there is more than one primary key column, use @where parameter instead to specify which rows to process.', 16, 1)
			GOTO error
		END

		CREATE TABLE #ids (orderBy INT, id INT)

		IF CHARINDEX('-', @ids) <> 0
		BEGIN
			BEGIN TRY
				INSERT INTO #ids (orderBy, id)
				SELECT orderBy, id
				FROM internals.splitIds(@ids, '-')

				SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR
			END TRY
			BEGIN CATCH
				SET @error = -1
			END CATCH

			IF @rowcount <> 2 OR @error <> 0
			BEGIN
				RAISERROR('Invalid @ids parameter ''%s'', to specify a range pass in e.g. ''1-9''.', 16, 1, @ids)
				GOTO error
			END

			SELECT @i = 0, @idsWhere = '('

			SELECT @idsWhere = @idsWhere + CASE WHEN @i = 0 THEN '' ELSE ' AND ' END + '[ours].' + kc.quotedName + CASE WHEN @i = 0 THEN ' >= ' ELSE ' <= ' END + CAST(i.id AS NVARCHAR(MAX)), @i = @i + 1
			FROM #ids i
			FULL OUTER JOIN @key_columns kc
			ON 1 = 1
			ORDER BY i.orderBy

			SELECT @i = 0, @idsWhere = @idsWhere + ') OR ('

			SELECT @idsWhere = @idsWhere + CASE WHEN @i = 0 THEN '' ELSE ' AND ' END + '[theirs].' + m.quotedName + CASE WHEN @i = 0 THEN ' >= ' ELSE ' <= ' END + CAST(i.id AS NVARCHAR(MAX)), @i = @i + 1
			FROM #ids i
			FULL OUTER JOIN @key_columns kc
			ON 1 = 1
			INNER JOIN @mapped_columns m
			ON kc.column_id = m.column_id
			ORDER BY i.orderBy

			SELECT @i = 0, @idsWhere = @idsWhere + ')'
		END
		ELSE
		BEGIN
			BEGIN TRY
				INSERT INTO #ids (orderBy, id)
				SELECT orderBy, id
				FROM internals.splitIds(@ids, ',')

				SELECT @rowcount = @@ROWCOUNT, @error = @@ERROR
			END TRY
			BEGIN CATCH
				SET @error = -1
			END CATCH

			IF @rowcount = 0 OR @error <> 0
			BEGIN
				RAISERROR('Invalid @ids parameter ''%s'', to specify a set pass in e.g. ''1,2,3''.', 16, 1, @ids)
				GOTO error
			END

			SELECT @i = 0, @idsWhere = ''

			SELECT @idsWhere =
				@idsWhere +
				CASE WHEN @i = 0 THEN '' ELSE ' OR ' END +
				'[ours].' + kc.quotedName + ' = ' + CAST(i.id AS NVARCHAR(MAX)) +
				' OR ' +
				'[theirs].' + m.quotedName + ' = ' + CAST(i.id AS NVARCHAR(MAX)),
				@i = @i + 1
			FROM #ids i
			FULL OUTER JOIN @key_columns kc
			ON 1 = 1
			INNER JOIN @mapped_columns m
			ON kc.column_id = m.column_id
			ORDER BY i.orderBy
		END
	END

	RETURN 0

error:
	RETURN -1
END
GO
