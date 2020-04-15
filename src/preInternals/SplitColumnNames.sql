SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE FUNCTION [internals].[SplitColumnNames] (
	@columnNames NVARCHAR(MAX)
) RETURNS @columnNamesTable TABLE (quoted_name internals.QuotedName not null)
AS
BEGIN
	DECLARE @index int
	DECLARE @column NVARCHAR(MAX)
	DECLARE @server sysname
	DECLARE @database sysname
	DECLARE @schema sysname
	DECLARE @done bit = 0

	WHILE @done = 0
	BEGIN
		SET @index = CHARINDEX(',', @columnNames)
		IF (@index < 1) SELECT @index = LEN(@columnNames) + 1, @done = 1

		SELECT @column = LTRIM(RTRIM(SUBSTRING(@columnNames, 1, @index - 1)))

		SELECT
			@server = PARSENAME(@column, 4),
			@database = PARSENAME(@column, 3),
			@schema = PARSENAME(@column, 2),
			@column = PARSENAME(@column, 1)

		-- intentionally cause error (best we can do to report illegal column name)
		IF (@server IS NOT NULL OR @database IS NOT NULL OR @schema IS NOT NULL)
			SET @column = NULL

		INSERT INTO @columnNamesTable SELECT QUOTENAME(@column)

		IF @done = 0
			SET @columnNames = SUBSTRING(@columnNames, @index + 1, LEN(@columnNames))
	END

	RETURN
END
GO
