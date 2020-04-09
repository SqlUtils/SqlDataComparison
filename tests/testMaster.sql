USE SqlUtils
GO

EXEC tSQLt.NewTestClass 'testMaster';
GO

CREATE PROCEDURE testMaster.[test basic compare using master to locate current db works]
AS
BEGIN
	DECLARE @CRLF CHAR(2) = CHAR(13) + CHAR(10)

	DECLARE @Message NVARCHAR(MAX) =
		'Data differences found between OURS <<< [SqlUtilsTests_A].[dbo].[AddressTypes] and THEIRS >>> [SqlUtilsTests_B].[dbo].[AddressTypes].' + @CRLF +
		' - Switch to results window to view differences.' + @CRLF +
		' - Call [Import|Export][Added|Deleted|Changed|All] (e.g. ImportAdded) with the same arguments to transfer changes.' + @CRLF

	EXEC tSQLt.ExpectException @Message, 16, 1

	EXEC('USE SqlUtilsTests_A; EXEC sp_CompareData ''AddressTypes'', ''SqlUtilsTests_B..AddressTypes''')

END
GO
