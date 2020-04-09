/*[[LICENSE]]*/

Installation:

 - Run Install.sql on your development server
 - Optionally run IntallMaster.sql on your *development* server to install
   thin wrapper commands in the master database which can detect the current
   database (see below)

To uninstall, run `CleanMaster.sql` (only required if you previously ran
`InstallMaster.sql`), then simply delete the `SqlUtils` database to remove
everything else.

Then compare data with:

  EXEC SqlUtils.CompareData '<db1>.[<schema1>].<table1>', '<db1>.[<schema2>].<table2>'

Or:

  -- defaults to current database
  EXEC sp_CompareData '<table1>', '<db1>.[<schema2>].<table2>'

Followed by:

  EXEC [Import|Export][Added|Deleted|Changed|All] (e.g. ImportAdded) with the same arguments to transfer changes

To see what would happen without commiting to the changes use, e.g.:

  BEGIN TRANSACTION
  EXEC ImportAdded <args>
  ROLLBACK TRANSACTION

In addition to specifying 'our' and 'their' databases as above, additional arguments include:

 - @use: manually specify the columns to consider when comparing the two tables, e.g. 'col1, col2'
 - @join: manually specify the column(s) on which to join our and their table, e.g. 'col1, col2'
 - @map: string containing mapping between our and their columns, e.g. 'col1, map_col1; col2, map_col2'
 - @ids: string containing range or set of ids to process, e.g. '1, 2, 3, 5, 9', '2-17'
 - @where: detailed where condition constraining which rows to process, specify columns with 'ours' or
           'theirs', e.g. 'ours.valid = 1'
 - @show_sql: show the generated SQL *as well as running it*; especially useful in combination with the
              'ROLLBACK TRANSACTION' trick above, to be sure what will happen before committing to it
 - @interleave: set to 1 to use alternative diff view, which may make it easier to see some types of changes
