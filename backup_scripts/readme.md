# Backup

## Set up
Place scriptsd in directory eg /oracle/backups
Give appropriate permisions
## Use
To see options
```
./db_backup.sh -h

Usage:  db_backup.sh -s DBNAME -b BACKUPDIR [ -t -p -d -r -y -z -g -h -c -a -k -e ]

-s : database sid you want to backup
-b : base backup directory
-t : backup type                     Options : FULL_BACKUP|ARCHIVELOGS_ONLY      Default : FULL_BACKUP
-p : rman threads                    Options : any int                           Default : 4
-d : rman deletion policy            Options : DEL_ALL_BK_FIRST|DELETE_OBSOLETE  Default : DELETE_OBSOLETE
-r : rsync action                    Options : NOSYNC|WHOLE_BACKUP|POST_ZIP      Default : NOSYNC
-y : rsync to server                 Options : any ip or hostname                Default : NOWHERE
-z : remote directory                Options : any dir                           Default : NOWHERE
-g : rsync to server 2               Options : any ip or hostname                Default : NOWHERE
-h : remote directory server 2       Options : any dir                           Default : NOWHERE
-c : compression                     Options : RMAN|ZIP|NOCOMPRESS               Default : RMAN
-a : zip threads                     Options : any int                           Default : ALL
-k : Days of zips to keep, not rman  Options : any int                           Default : 1
-e : backup standby control file     Options : FOR_STANDBY|NOT_FOR_STANDBY       Default : NOT_FOR_STANDBY

eg : db_backup.sh -s DB1 -b /oracle/backups -t ARCHIVELOGS_ONLY -r POST_ZIP -y db2.local -z /oracle/backups/from_db1 -c ZIP
--
-- This will :
--   backup archivelogs for database DB1 to /oracle/backups directory
--   then use parallel gzip compression on the backup
--   then rsync this file to db2.local, remote directory /oracle/backups/from_db1
--
```
### Example output
```
[oracle@dbsrv1 scripts]$ /u01/db_backup/scripts/db_backup.sh -s db1 -b /u01/db_backup -t ARCHIVELOGS_ONLY

-------------------------------------------------------------------

Start : Thu Jun 16 10:54:12 BST 2016

-------------------------------------------------------------------


ORASID                : ecnrdev1
BACKUP_TYPE           : ARCHIVELOGS_ONLY
RMAN_PROCESSES        : 4
BASE_DIR              : /u01/db_backup
BACKUP_DIR            : /u01/db_backup/files/DB1/dbsrv1.local
DEL                   : DELETE_OBSOLETE
FOR_STANDBY           : NOT_FOR_STANDBY
SYNC_ACTION           : NOSYNC
SYNC BACKUP           : NOSYNC
SYNC_TO               : NOWHERE
SYNC_TO_DIR           : NOWHERE
SYNC_TO_2             : NOWHERE
SYNC_TO_DIR_2         : NOWHERE
RMAN COMPRESSION      : COMPRESS
POST_COMPRESS         : NOCOMPRESS
POST_COMPRESS_THREADS : ALL
POST_RM_FILE_AGE_DAYS : 1
POST_COMPRESS_RSYNC   : NOSYNC

Backup Args           : db1 ARCHIVELOGS_ONLY 4 /u01/db_backup DELETE_OBSOLETE NOT_FOR_STANDBY COMPRESS

Logging to            : /u01/db_backup/logs/backup_dbsrv1.local_db1_ARCHIVELOGS_ONLY_2016_06_16.log


Elapsed : 4 secs for RMAN Backup


Total Elapsed Seconds : 4


-------------------------------------------------------------------

End : Thu Jun 16 10:54:16 BST 2016

-------------------------------------------------------------------
```
## Rsync backup files
Set up key exchange between locations
Use the rsync option
## Backup all databases in the oratab in one command
use backup_all_dbs.pl
eg
```
backup_all_dbs.pl --type FULL_BACKUP      --rman_channels 1 --base_dir /u01/db_backup
backup_all_dbs.pl --type ARCHIVELOGS_ONLY --rman_channels 1 --base_dir /u01/db_backup
```
### Custom options per db
```
mkdir <SCRIPTS_DIR>/config
```
Add file hostname.xml to the config dir
config file format example
```
<db_list>
  <db name="db1">
    <sync_to_1>bk_server1</sync_to_1>
    <sync_to_1_dir>/oracle/backups/files/db1</sync_to_1_dir>
    <sync_to_2>bk_server2</sync_to_2>
    <sync_to_2_dir>/oracle/backups/files/db2</sync_to_2_dir>
    <compression>ZIP</compression>
    <rsync_option>POST_ZIP</rsync_option>
  </db>
</db_list>
```

