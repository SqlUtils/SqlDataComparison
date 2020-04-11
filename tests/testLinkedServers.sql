USE master
GO

IF NOT EXISTS(select * from sys.servers where is_linked = 1 and name = 'localhost')
BEGIN
  EXEC sp_addlinkedserver @server = 'localhost', @srvproduct = 'SQL Server'
END
GO

USE SqlUtils
GO

EXEC tSQLt.NewTestClass 'testLinkedServers';
GO

CREATE PROCEDURE testLinkedServers.[test illegal linked server for ours warning works]
AS
BEGIN
	EXEC tSQLt.ExpectException @ExpectedMessagePattern = 'Could not find server ''xyz'' in sys.servers.%'
	EXEC CompareData 'xyz.a..b', ''
END
GO

CREATE PROCEDURE testLinkedServers.[test illegal linked server for theirs warning works]
AS
BEGIN
	EXEC tSQLt.ExpectException @ExpectedMessagePattern = 'Could not find server ''xyz'' in sys.servers.%'
	EXEC CompareData 'SQLUtilsTests_A..AddressTypes', 'xyz.a..b'
END
GO

CREATE PROCEDURE testLinkedServers.[test illegal linked server table for ours warning works]
AS
BEGIN
	EXEC tSQLt.ExpectException 'Cannot find database [a] on linked server [localhost]'
	EXEC CompareData 'localhost.a..b', ''
END
GO

CREATE PROCEDURE testLinkedServers.[test illegal linked server table for theirs warning works]
AS
BEGIN
	EXEC tSQLt.ExpectException 'Cannot find database [a] on linked server [localhost]'
	EXEC CompareData 'SQLUtilsTests_A..AddressTypes', 'localhost.a..b'
END
GO

CREATE PROCEDURE testLinkedServers.[test no default sp_ database on ours when linked server]
AS
BEGIN
	EXEC tSQLt.ExpectException 'Invalid or missing database name in parameter @ourTableName = ''localhost...AddressTypes'''
	EXEC sp_CompareData 'localhost...AddressTypes', 'SQLUtilsTests_A..AddressTypes'
END
GO

CREATE PROCEDURE testLinkedServers.[test no default sp_ database on theirs when linked server]
AS
BEGIN
	EXEC tSQLt.ExpectException 'Invalid or missing database name in parameter @theirTableName = ''localhost...AddressTypes'''
	EXEC sp_CompareData 'SQLUtilsTests_A..AddressTypes', 'localhost...AddressTypes'
END
GO
