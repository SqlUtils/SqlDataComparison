SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE FUNCTION [internals].[SplitColumnMap] (
	@map NVARCHAR(MAX)
) RETURNS @column_mapping TABLE (quoteName internals.QuotedName not null, quoteRename internals.QuotedName not null)
AS
BEGIN
	DECLARE @index int
	DECLARE @innerIndex int

	DECLARE @columnPair NVARCHAR(MAX)

	DECLARE @server sysname
	DECLARE @database sysname
	DECLARE @schema sysname

	DECLARE @from NVARCHAR(MAX)
	DECLARE @to NVARCHAR(MAX)

	DECLARE @done bit = 0

	WHILE @done = 0
	BEGIN
		SET @index = CHARINDEX(';', @map)
		IF (@index < 1) SELECT @index = LEN(@map) + 1, @done = 1

		SELECT @columnPair = LTRIM(RTRIM(SUBSTRING(@map, 1, @index - 1)))

		SET @innerIndex = CHARINDEX(',', @columnPair)
		IF @innerIndex < 1
			-- intentional error
			SELECT @from = NULL, @to = NULL
		ELSE
		BEGIN
			SELECT @from = LTRIM(RTRIM(SUBSTRING(@columnPair, 1, @innerIndex - 1)))
			SELECT @to = LTRIM(RTRIM(SUBSTRING(@columnPair, @innerIndex + 1, LEN(@columnPair))))

			SELECT
				@server = PARSENAME(@from, 4),
				@database = PARSENAME(@from, 3),
				@schema = PARSENAME(@from, 2),
				@from = PARSENAME(@from, 1)

			-- intentionally cause error (best we can do to report illegal column name)
			IF (@server IS NOT NULL OR @database IS NOT NULL OR @schema IS NOT NULL)
				SET @from = NULL

			SELECT
				@server = PARSENAME(@to, 4),
				@database = PARSENAME(@to, 3),
				@schema = PARSENAME(@to, 2),
				@to = PARSENAME(@to, 1)

			-- intentionally cause error (best we can do to report illegal column name)
			IF (@server IS NOT NULL OR @database IS NOT NULL OR @schema IS NOT NULL)
				SET @to = NULL
		END

		-- nulls above intentionally cause error here
		INSERT INTO @column_mapping SELECT QUOTENAME(@from), QUOTENAME(@to)

		IF @done = 0
			SET @map = SUBSTRING(@map, @index + 1, LEN(@map))
	END

	RETURN
END
GO
