SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*[[LICENSE]]*/
CREATE PROCEDURE [internals].[ValidateColumns]
	@test_columns internals.ColumnsTable READONLY,
	@allowed_columns internals.ColumnsTable READONLY,
	@msg_lquot NVARCHAR(1),
	@msg_rquot NVARCHAR(1),
	@msg_singular NVARCHAR(MAX),
	@msg_plural NVARCHAR(MAX),
	@msg_table_name NVARCHAR(MAX)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @rowcount INT
	DECLARE @illegal_columns NVARCHAR(MAX)
	DECLARE @msg NVARCHAR(MAX)

	-- gather illegal column names (if any) into a single string using FOR XML PATH; have to use CTE with this in order to get the count
	SET @rowcount = 0;
	WITH IllegalColumns_CTE (quoted_name)
	AS
	(
		SELECT t.quoted_name
		FROM @test_columns t
		LEFT OUTER JOIN @allowed_columns c
		ON t.quoted_name = c.quoted_name
		WHERE c.quoted_name IS NULL
	)
	SELECT
		@illegal_columns = STUFF(
		(
			SELECT ', ' + @msg_lquot + quoted_name + @msg_rquot
			FROM IllegalColumns_CTE
			FOR XML PATH('')
		), 1, 2, ''),
		@rowcount = (SELECT COUNT(*) FROM IllegalColumns_CTE)

	IF @illegal_columns <> ''
	BEGIN
		IF @rowcount = 1
			SET @msg = @msg_singular
		ELSE
			SET @msg = @msg_plural

		RAISERROR(@msg, 16, 1, @illegal_columns, @msg_table_name)
		GOTO error
	END

	RETURN 0

error:
	RETURN -1
END
GO
