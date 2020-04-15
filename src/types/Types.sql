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
	quoted_name internals.QuotedName
)
GO

-- pre-quoted column names
CREATE TYPE internals.ColumnsMap AS TABLE
(
	quoted_name internals.QuotedName,
	quoted_rename internals.QuotedName
)
GO
