EXEC tSQLt.NewTestClass 'testMidAbbrev';
GO

CREATE PROCEDURE testMidAbbrev.internalTestMidAbbrev
	@toAbbreviate NVARCHAR(MAX),
	@length INT,
	@expectedResult NVARCHAR(MAX)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @len INT = LEN(@expectedResult)
	EXEC tSQLt.AssertEquals @length, @len

	DECLARE @abbreviated NVARCHAR(MAX) = internals.MidAbbrev(@toAbbreviate, @length)
	EXEC tSQLt.AssertEqualsString @expectedResult, @abbreviated
END
GO

CREATE PROCEDURE testMidAbbrev.[test MidAbbrev works]
AS
BEGIN
	SET NOCOUNT ON;

	EXEC testMidAbbrev.internalTestMidAbbrev '12345678', 3, '...'
	EXEC testMidAbbrev.internalTestMidAbbrev '12345678', 4, '1...'
	EXEC testMidAbbrev.internalTestMidAbbrev '12345678', 5, '1...8'
	EXEC testMidAbbrev.internalTestMidAbbrev '12345678', 6, '12...8'
	EXEC testMidAbbrev.internalTestMidAbbrev '12345678', 7, '12...78'
	EXEC testMidAbbrev.internalTestMidAbbrev '12345678', 8, '12345678'
END
GO
