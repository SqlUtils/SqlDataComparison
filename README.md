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

When viewing data differences interleaved results (`@interleave = 1`, the default) make it more easy to see differences but will only show used and mapped columns; non-interleaved results (`@interleave = 0`) will show all columns from both tables, even if they are not in the used and mapped set.