#DBSync 
DBSync automates the creation and updates of a standby database
DBSync uses RMAN and RSYNC to do this
##setup
Install Oracle software only to a second machine ( or clone the oracle home )
place scripts in directory eg /oracle/dbsync
##Start a new standby instance
```
[oracle@<STANDBY> ~]$ /oracle/dbsync/scripts/new_instance.sh \
<STANDBY_SID> <PRIMARY_DB_NAME> <SGA_SIZE> <PGA_SIZE> <FRA_SIZE> \
<DBSYNC_CONFIG_DIR <BACKUP_FILES_DIR>
 
Eg
[oracle@<STANDBY> ~]$ /oracle/dbsync/scripts/new_instance.sh \
ecasedev1_10 ecasedev 300M 300M 30G \
/oracle/dbsync/config /oracle/fra/backups/<SID>
```
Update file locations for standby and primary host and primary log location
```
vi /oracle/dbsync/config/HOSTNAME_SID.sh
```

MORE COMMING
