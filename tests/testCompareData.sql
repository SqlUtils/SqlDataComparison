USE SqlUtils
GO

EXEC tSQLt.NewTestClass 'testCompareData';
GO

CREATE PROCEDURE testCompareData.[test basic compare works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
		'Data differences found between OURS <<< [SqlUtilsTests_A].[dbo].[AddressTypes] and THEIRS >>> [SqlUtilsTests_B].[dbo].[AddressTypes].' + @CRLF +
		' - Switch to results window to view differences.' + @CRLF +
		' - Call [Import|Export][AddedRows|DeletedRows|ChangedRows|All] (e.g. ImportAddedRows) with the same arguments to transfer changes.' + @CRLF

	EXEC tSQLt.ExpectException @Message, 16, 1

	EXEC CompareData 'SqlUtilsTests_A..AddressTypes', 'SqlUtilsTests_B..AddressTypes'

END
GO
