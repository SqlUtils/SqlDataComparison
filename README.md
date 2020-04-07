# SqlDataComparison

Pure SQL data comparison and reconciliation utility:

* `sp_comparedata 'MyTable', 'RemoteDb..MyTable'`
* `sp_exportall 'MyTable', 'RemoteDb..MyTable'`
* etc.

With support for:

* Column name remapping
* Columns filter
* Automatic (primary key based) or manual join columns spec

Build with `msbuild` or `dotnet build`, clean with `msbuild -target:clean` or `dotnet build -target:clean`.

When viewing data differences interleaved results (`@interleave = 1`) make it more easy to see column-by-column differences, but can only show used and mapped columns and may make it harder to see which whole rows are going to be affected by data reconciliation commands; non-interleaved results (`@interleave = 0`, the default) will show all columns from both tables, even if they are not in the used and mapped set, and may make it easier to see which rows will be affected by data reconciliation commands.