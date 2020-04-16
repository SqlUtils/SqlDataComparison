# ![logo](https://raw.githubusercontent.com/SqlUtils/SqlDataComparison/master/src/static/logo_32x32.png) SqlDataComparison

## Installation:

[![NuGet](https://img.shields.io/nuget/v/SqlUtils.SqlDataComparison.svg)](https://nuget.org/packages/SqlUtils.SqlDataComparison)

To get the release files:

 - Either download then unzip the [latest release](https://github.com/SqlUtils/SqlDataComparison/releases) hosted here
 - Or add the current [NuGet package](https://nuget.org/packages/SqlUtils.SqlDataComparison) to any .NET Core or .NET Framework project; the release files will automatically appear in a new `SqlDataComparison` virtual directory (or actual directory, for older NuGet clients) in your project

Then:

 - Run `Install.sql` on your development SQL Server
 - Optionally also run `InstallMaster.sql` on your *development* server, to add thin wrapper commands in the master database which can detect the current database, see below

Do not use `InstallMaster.sql` on a production server - this is normal SQL Server good practice.

To uninstall, run `CleanMaster.sql` (only required if you previously ran `InstallMaster.sql`) then simply delete the `SqlUtils` database to remove everything else.

## Usage

Compare data with:

```sql
EXEC SqlUtils.CompareData '[linked-server1.]<db1>.[<schema1>].<table1>', '[linked-server2.]<db2>.[<schema2>].<table2>'
```

E.g.:

```sql
-- schema defaults to dbo
EXEC SqlUtils.CompareData 'db1..table1', 'db2..table2'
```

Or:

```sql
-- 'ours' table defaults to current database, this requires (optional) install of wrapper sp_ commands in the development server master db
EXEC sp_CompareData 'table1', 'db2..table2'
```

Followed by:

```
EXEC [Import|Export][Added|Deleted|Changed|All] (e.g. ImportAdded) with the same arguments to transfer changes.
```

E.g.:

```sql
EXEC sp_ExportAll 'table1', 'db2..table2'
```

To see what would happen without commiting the changes use the following pattern:

```sql
BEGIN TRANSACTION
EXEC sp_ExportAll 'table1', 'db2..table2'
ROLLBACK TRANSACTION
```

and then look at the SSMS Messages window to see what went on.

In addition to specifying 'ours' and 'theirs' tables as above, the following optional additional parameters are available:

 - `@use`: the columns to consider when comparing the two tables, e.g. `'col1, col2'`
 - `@join`: the column(s) on which to join the 'ours' and 'theirs' tables, e.g. `'col1, col2'`; the default is the primary key column(s) of 'ours'
 - `@map`: the mapping between 'ours' and 'theirs' columns, e.g. `'col1, map_col1; col2, map_col2'`
 - `@ids`: range or set of ids to process, e.g. `'2-7'` or `'1, 2, 3, 5, 9'` (applicable to a single integer join/key column only; use `@where` for more complicated scenarios)
 - `@where`: where condition constraining which rows to process; qualify columns with 'ours' or 'theirs', e.g. `'ours.valid = 1'`
 - `@showSql`: show the generated SQL *as well as running it*; especially useful in combination with the `ROLLBACK TRANSACTION` trick shown above, to be sure of what will happen before committing it
 - `@interleave`: set to `1` to use an alternative diff view, which may make it easier to see some types of row differences

## Development

Clone the GitHub repository.

Download a copy of [tSQLt](tsqlt.org) and unpack it so that `/OpenSource/tSQLt_V1.0.5873.27393/tSQLt.class.sql` exists (or unpack it somewhere else - as far as I know, there is no strong requirement for a particular version of tSQLt as long as it's at least the version shown here - in which case modify the path to `tSQLt.class.sql` in `SqlDataComparison.proj` to match before building).

Build with `msbuild` or `dotnet build`.

Clean with `msbuild -target:clean` or `dotnet build -target:clean`.

After building, run the contents of the following files from the `build` directory on the development SQL Server, in the following order, to install the project and tests:

```
Install.sql
InstallMaster.sql
tests\InstallTSQLt.sql
tests\InstallTests.sql
```

Run all tests with `EXEC tSQLt.RunAll`.
