--
-- $Id: //Infrastructure/GitHub/Database/backup_and_sync/dbsync/primary_database_code/sys_grants.sql#4 $
--
GRANT SELECT ON v_$archived_log TO dbamgr
/
GRANT SELECT ON v_$log TO dbamgr
/
GRANT EXECUTE ON dbms_flashback TO dbamgr
/
GRANT READ,WRITE ON DIRECTORY dbsync_logs_1 TO dbamgr
/
