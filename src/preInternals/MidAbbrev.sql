SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE FUNCTION [internals].[MidAbbrev](
	@string NVARCHAR(MAX),
	@max_length INT
)
RETURNS sysname
AS
BEGIN
	DECLARE @over INT = LEN(@string) - @max_length
	IF @over > 0
	BEGIN
		SET @string = SUBSTRING(@string, 1, ((LEN(@string) - @over) / 2) - 1) + '...' + SUBSTRING(@string, ((LEN(@string) + @over)/2) + 3, LEN(@string))
	END
	RETURN @string
END
GO
