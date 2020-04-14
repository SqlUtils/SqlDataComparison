SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE FUNCTION [internals].[SplitIds] (
	@ids NVARCHAR(MAX),
	@splitChar CHAR(1)
) RETURNS @idsTable TABLE (orderBy int not null, id int not null)
AS
BEGIN
	DECLARE @index int
	DECLARE @orderBy int = 0
	DECLARE @id NVARCHAR(MAX)
	DECLARE @done bit = 0

	WHILE @done = 0
	BEGIN
		SET @index = CHARINDEX(@splitChar, @ids)
		IF (@index < 1) SELECT @index = LEN(@ids) + 1, @done = 1

		SELECT @id = LTRIM(RTRIM(SUBSTRING(@ids, 1, @index - 1)))

		-- intentionally cause error (best we can do to report empty string)
		IF @id = ''
			SET @id = 'empty-string'

		INSERT INTO @idsTable (orderBy, id) SELECT @orderBy, @id

		IF @done = 0
      SELECT @ids = SUBSTRING(@ids, @index + 1, LEN(@ids)), @orderBy = @orderBy + 1
	END

	RETURN
END
GO
