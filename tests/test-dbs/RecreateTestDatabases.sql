/*
 * TEST DATABASE A
 */

USE tempdb;
GO

IF EXISTS(select * from sys.databases where name='SqlUtilsTests_A')
BEGIN
	ALTER DATABASE SqlUtilsTests_A SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE SqlUtilsTests_A
END
GO

CREATE DATABASE SqlUtilsTests_A
GO

/*
 * TEST DATABASE B
 */

USE tempdb;
GO

IF EXISTS(select * from sys.databases where name='SqlUtilsTests_B')
BEGIN
	ALTER DATABASE SqlUtilsTests_B SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE SqlUtilsTests_B
END
GO

CREATE DATABASE SqlUtilsTests_B
GO

/*
 * TEST DATABASE C
 */

USE tempdb;
GO

IF EXISTS(select * from sys.databases where name='SqlUtilsTests_C')
BEGIN
	ALTER DATABASE SqlUtilsTests_C SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE SqlUtilsTests_C
END
GO

CREATE DATABASE SqlUtilsTests_C
GO
