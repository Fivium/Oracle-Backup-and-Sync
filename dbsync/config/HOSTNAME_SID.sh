#!/bin/sh
#
# $Id: //Infrastructure/GitHub/Database/backup_and_sync/dbsync/config/HOSTNAME_SID.sh#3 $
#
# Config for dbsync
# - __ITEM__  placeholders will be replace automatically by new_instance.sh
# - other values can be set in here
#

#
# Backup files from primary
#
BACKUP_FILES_DIR='__DB_BACKUP_PATH__'
#
# Restore scripts, these are located in the dbsync scripts directory
#
RESTORE_SCRIPTS_DIR='/oracle/db_backup/dbsync/scripts'
#
# recovery file area
# - this is used for the oracle parameter db_recovery_file_dest
# - it does not need the db name in the path
#
FRA_DIR='/oracle/fra'
#
# Location for controlfiles and online redo
# - dbsync enforces 2 location multiplex
#
MULTIPLEX1_DIR='/oracle/multiplex1'
MULTIPLEX2_DIR='/oracle/fra/multiplex2'
#
# Datafile file location for standby datafiles
# - this is used for the oracle parameter db_create_file_dest
# - it does not need the db name in the path
#
NEW_DATAFILE_DIR='/oracle/oradata'
#
# dbsync log location
#
LOGFILE_DIR='/oracle/db_backup/dbsync/logs/__STANDBY_HOST______STANDBY_SID__'
#
# name of the database
#
DB_NAME='__DB_NAME__'
#
# Primary host info for syncing logs back
# - Can be left blank if you don't need the logs synced
#
PRIMARY_HOST=
PRIMARY_LOGFILE_BASE_DIR=

