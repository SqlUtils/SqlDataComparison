IF EXISTS(SELECT * FROM sys.objects WHERE schema_id = 1 AND type = 'P' AND name = 'sp_ImportChanged')
	DROP PROCEDURE sp_ImportChanged
GO
