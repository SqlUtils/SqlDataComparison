USE tempdb;
GO

/*
 * TEST DATABASE A
 */
IF EXISTS(select * from sys.databases where name='SqlUtilsTests_A')
BEGIN
	ALTER DATABASE SqlUtilsTests_A SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE SqlUtilsTests_A
END
GO

/*
 * TEST DATABASE B
 */
IF EXISTS(select * from sys.databases where name='SqlUtilsTests_B')
BEGIN
	ALTER DATABASE SqlUtilsTests_B SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE SqlUtilsTests_B
END
GO

/*
 * TEST DATABASE C
 */
IF EXISTS(select * from sys.databases where name='SqlUtilsTests_C')
BEGIN
	ALTER DATABASE SqlUtilsTests_C SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE SqlUtilsTests_C
END
GO
