SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [internals].[SplitColumnRenames] (
	@columnRenames NVARCHAR(MAX)
) RETURNS @columnRenamesTable TABLE (name sysname not null, rename sysname not null)
AS
BEGIN
	DECLARE @index int
	DECLARE @innerIndex int

	DECLARE @columnPair sysname

	DECLARE @server sysname
	DECLARE @database sysname
	DECLARE @schema sysname

	DECLARE @from sysname
	DECLARE @to sysname

	DECLARE @done bit = 0

	WHILE @done = 0
	BEGIN
		SET @index = CHARINDEX(';', @columnRenames)
		IF (@index < 1) SELECT @index = LEN(@columnRenames) + 1, @done = 1

		SELECT @columnPair = LTRIM(RTRIM(SUBSTRING(@columnRenames, 1, @index - 1)))

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

		INSERT INTO @columnRenamesTable SELECT @from, @to

		IF @done = 0 SET @columnRenames = SUBSTRING(@columnRenames, @index + 1, LEN(@columnRenames))
	END

	RETURN
END
GO