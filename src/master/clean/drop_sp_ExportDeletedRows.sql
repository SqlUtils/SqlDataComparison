IF EXISTS(SELECT * FROM sys.objects WHERE schema_id = 1 AND type = 'P' AND name = 'sp_ExportDeleted')
	DROP PROCEDURE sp_ExportDeleted
GO
