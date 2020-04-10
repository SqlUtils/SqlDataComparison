USE SqlUtils
GO

EXEC tSQLt.NewTestClass 'testIds';
GO

CREATE PROCEDURE testIds.[test basic ids set param works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
		'Data differences found between OURS <<< [SqlUtilsTests_B].[dbo].[AddressTypes] and THEIRS >>> [SqlUtilsTests_A].[dbo].[AddressTypes].' + @CRLF +
		' - Switch to results window to view differences.' + @CRLF +
		' - Call [Import|Export][Added|Deleted|Changed|All] (e.g. ImportAdded) with the same arguments to transfer changes.' + @CRLF

	EXEC tSQLt.ExpectException @Message, 16, 1

	-- TO DO: This needs to work whichever side @ids matches on, but currently only checks ours side
	EXEC CompareData 'SqlUtilsTests_B..AddressTypes', 'SqlUtilsTests_A..AddressTypes', @ids = '2'
END
GO

CREATE PROCEDURE testIds.[test basic ids range param works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
		'Data differences found between OURS <<< [SqlUtilsTests_B].[dbo].[AddressTypes] and THEIRS >>> [SqlUtilsTests_A].[dbo].[AddressTypes].' + @CRLF +
		' - Switch to results window to view differences.' + @CRLF +
		' - Call [Import|Export][Added|Deleted|Changed|All] (e.g. ImportAdded) with the same arguments to transfer changes.' + @CRLF

	EXEC tSQLt.ExpectException @Message, 16, 1

	-- TO DO: This needs to work whichever side @ids matches on, but currently only checks ours side
	EXEC CompareData 'SqlUtilsTests_B..AddressTypes', 'SqlUtilsTests_A..AddressTypes', @ids = '1-2'
END
GO

CREATE PROCEDURE testIds.[test empty ids param reported correctly]
AS
BEGIN
	EXEC tSQLt.ExpectException 'Invalid @ids parameter '''', to specify a set pass in e.g. ''1,2,3''.', 16, 1

	EXEC CompareData 'SqlUtilsTests_B..AddressTypes', 'SqlUtilsTests_A..AddressTypes', @ids = ''
END
GO

CREATE PROCEDURE testIds.internalTestIllegalIdsSetParam
	@ids NVARCHAR(MAX)
AS
BEGIN
	DECLARE @message NVARCHAR(MAX) = 'Invalid @ids parameter ''' + @ids + ''', to specify a set pass in e.g. ''1,2,3''.'

	EXEC tSQLt.ExpectException @message, 16, 1

	EXEC CompareData 'SqlUtilsTests_B..AddressTypes', 'SqlUtilsTests_A..AddressTypes', @ids = @ids
END
GO

CREATE PROCEDURE testIds.[test malformed ids set param reported correctly #1]
AS
BEGIN
	EXEC testIds.internalTestIllegalIdsSetParam ','
END
GO

CREATE PROCEDURE testIds.[test malformed ids set param reported correctly #2]
AS
BEGIN
	EXEC testIds.internalTestIllegalIdsSetParam '1,'
END
GO

CREATE PROCEDURE testIds.[test malformed ids set param reported correctly #3]
AS
BEGIN
	EXEC testIds.internalTestIllegalIdsSetParam '2,'
END
GO

CREATE PROCEDURE testIds.internalTestIllegalIdsRangeParam
	@ids NVARCHAR(MAX)
AS
BEGIN
	DECLARE @message NVARCHAR(MAX) = 'Invalid @ids parameter ''' + @ids + ''', to specify a range pass in e.g. ''1-9''.'

	EXEC tSQLt.ExpectException @message, 16, 1

	EXEC CompareData 'SqlUtilsTests_B..AddressTypes', 'SqlUtilsTests_A..AddressTypes', @ids = @ids
END
GO

CREATE PROCEDURE testIds.[test malformed ids range param reported correctly #1]
AS
BEGIN
	EXEC testIds.internalTestIllegalIdsRangeParam '-'
END
GO

CREATE PROCEDURE testIds.[test malformed ids range param reported correctly #2]
AS
BEGIN
	EXEC testIds.internalTestIllegalIdsRangeParam '1-'
END
GO

CREATE PROCEDURE testIds.[test malformed ids range param reported correctly #3]
AS
BEGIN
	EXEC testIds.internalTestIllegalIdsRangeParam '-2'
END
GO

CREATE PROCEDURE testIds.[test malformed ids range param reported correctly #4]
AS
BEGIN
	EXEC testIds.internalTestIllegalIdsRangeParam '1-2-3'
END
GO
