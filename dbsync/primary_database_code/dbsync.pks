CREATE OR REPLACE PACKAGE DBAMGR.dbsync
--
-- T Dale 2014-02-10
--
-- Process the database sync logs from standby databases
--
-- $Id: //Infrastructure/GitHub/Database/backup_and_sync/dbsync/primary_database_code/dbsync.pks#1 $
AS
  PROCEDURE process_logs;
END;
/

