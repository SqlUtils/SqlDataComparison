-- 128 quoted ] + [ + ]
CREATE TYPE internals.QuotedName FROM NVARCHAR(258)
GO

-- two quoted names plus one .
CREATE TYPE internals.QuotedServerPlusTableName FROM NVARCHAR(517)
GO

-- four quoted names plus one .
CREATE TYPE internals.FourPartQuotedName FROM NVARCHAR(1035)
GO

-- pre-quoted column names
CREATE TYPE internals.ColumnsTable AS TABLE
(
	column_id int,
	quotedName internals.QuotedName
)
GO
