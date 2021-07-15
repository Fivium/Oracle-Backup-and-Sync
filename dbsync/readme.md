# DBSync 

DBSync automates the creation and updates of a standby database
DBSync uses RMAN and RSYNC to do this

## setup

Install Oracle software only to a second machine ( or clone the oracle home ) place scripts in directory eg /oracle/dbsync

check default values in 
```
HOSTNAME_SID.sh
```
```
init__ORACLE_SID__.ora
```
These are used to to create the run the standby
any __<name>__ will be replace when the config files for a new standby is created

### Start a new standby instance
```
[oracle@<STANDBY> ~]$ /oracle/dbsync/scripts/new_instance.sh \
<STANDBY_SID> <PRIMARY_DB_NAME> <SGA_SIZE> <PGA_SIZE> <FRA_SIZE> \
<DBSYNC_CONFIG_DIR <BACKUP_FILES_DIR>
 
Eg
[oracle@<STANDBY> ~]$ /oracle/dbsync/scripts/new_instance.sh \
db1_standby db1 300M 300M 30G \
/oracle/dbsync/config /oracle/fra/backups/<SID>
```

### Run backup on primary with syncing on
```
[oracle@<PRIMARY> ~]$ /home/oracle/backups/scripts/db_backup.sh -s <SID> -b <BACKUP_DIR> -t FULL_BACKUP -p 1 -c NOCOMPRESS -r WHOLE_BACKUP -y <STANDBY_SERVER> -z <STANDBY_BACKUP_DIR>
```
### Standby build
```
[oracle@<STANDBY> ~]$ screen
[oracle@<STANDBY> ~]$ /oracle/dbsync/scripts/dbsync_ctl.sh \
<STANDBY_SID> EXEC FULL NOOPEN NODROP
```
Check log file. It should end with no error and Recovery Manager complete.
### Test a rollforward
```
Archivelog backup primary
[oracle@<PRIMARY> ~]$ /home/oracle/backups/scripts/db_backup.sh -s <SID> -b <BACKUP_DIR> -t ARCHIVELOGS_ONLY -p 1 -c NOCOMPRESS -r WHOLE_BACKUP -y <STANDBY_SERVER> -z <STANDBY_BACKUP_DIR>
```
Roll forward standby
```
[oracle@<STANDBY> ~]$ /oracle/dbsync/scripts/dbsync_ctl.sh \
<STANDBY_SID> EXEC ROLLFORWARD NOOPEN
```
### Schedule nightly rebuild and roll forward
```
[oracle@<STANDBY> ~]$ crontab –e
*/10 09-16 * * * /oracle/dbsync/scripts/dbsync_ctl.sh <STANDBY_SID> EXEC ROLLFORWARD NOOPEN
23   17    * * * /oracle/dbsync/scripts/dbsync_ctl.sh <STANDBY_SID> EXEC FULL NOOPEN DROP
``` 
### Set primary to sync backups
For example:
```
44 18 * * * /oracle/fra/backups/scripts/backup_db_wrapper.sh /oracle/fra/backups db1 FULL_BACKUP 1 SYNC <STANDBY>
5,25,45 8-17 * * * /oracle/fra/backups/scripts/backup_db_wrapper.sh /oracle/fra/backups db1 ARCHIVELOGS_ONLY 1 SYNC <STANDBY>
```
