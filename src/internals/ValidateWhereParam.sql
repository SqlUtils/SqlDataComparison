SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[ValidateWhereParam]
	@where NVARCHAR(MAX)
AS
BEGIN
	SET NOCOUNT ON;

	IF @where IS NOT NULL AND CHARINDEX('ours', @where) = 0 AND CHARINDEX('theirs', @where) = 0
	BEGIN
		RAISERROR('Columns in @where parameter "%s" should be specified using ours.<colname> or theirs.<colname>', 16, 1, @where)
		GOTO error
	END

	RETURN 0

error:
	RETURN -1
END
GO
