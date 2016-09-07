#!/bin/sh
#
# Config for database sync
#
BACKUP_FILES_DIR='__DB_BACKUP_PATH__'
RESTORE_SCRIPTS_DIR='/oracle/db_backup/dbsync/scripts'
FRA_DIR='/oracle/fra'
MULTIPLEX1_DIR='/oracle/multiplex1'
MULTIPLEX2_DIR='/oracle/fra/multiplex2'
NEW_DATAFILE_DIR='__NEW_DATAFILE_DIR__'
LOGFILE_DIR='/oracle/db_backup/dbsync/logs/__STANDBY_HOST______STANDBY_SID__'
PRIMARY_HOST='__PRIMARY_HOST__'
PRIMARY_LOGFILE_BASE_DIR='/u01/db_backup/dbsync/logs'
