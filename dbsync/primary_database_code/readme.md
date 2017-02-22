# Process apply logs on primary

If you are syncing the apply logs back to primary and want to process them

First check the update location of logs in CREATE DIRECTORY in create_external_table_dbsync_logs.sql

    SQL> @create_external_table_dbsync_logs.sql

*************
If you add a second standby, you will need 2 directories, and do grants twice
************

    SQL> @sys_grants
 
    SQL> conn dbamgr
    SQL> @primary_db_objects.sql
    SQL> @dbsync.pks
    SQL> @dbsync.pkb
    SQL> @process_logs_job.sql
    now check the jobs
    SQL> col what format a30
    SQL> select what,to_char(next_date,'dd-mon-yyyy hh24:mi:ss') next_date,broken,failures from dba_jobs where schema_user='DBAMGR';
    If the logs are not on a common network area, then need to add and rsync to the standby box
