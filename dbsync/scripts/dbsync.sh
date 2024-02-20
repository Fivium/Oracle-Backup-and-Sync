#!/bin/bash
#
# $Id: //Infrastructure/GitHub/Database/backup_and_sync/dbsync/scripts/dbsync.sh#6 $
#
# T Dale 2010-03-15
# Auto restore or rollforward
#
LINE="------------------------------------------------------";
ERROR_STR="ERROR!!!"

function msg {
    echo "--"
    echo "-- INFO : $1"
    echo "--"
}
function create_dir_if_does_not_exist {
    if [ ! -d $2 ]; then
        echo $LINE
        echo "Directory for : \"$1\" does not exist"
        echo "Creating : \"$2\""
        mkdir -p $2
        echo $LINE
    fi

}
#
# Check dir exists
#
function check_exists {
    if [ ! -d "$2" ]; then
        echo $LINE
        echo $LINE
        echo "Directory : \"$2\" does not exist for parameter : \"$1\" "
        echo "-"
        echo "- This is set as a command line argument"
        echo "- OR in the config file : \"$CONFIG_FILE\" "
        echo "-"
        echo $LINE
        echo $LINE
        exit 1
    fi
}
#
# Run command
#
function run {
    echo " "
    echo "CMD Type  : $1"
    echo "TEST|EXEC : $2"
    echo "CMD args  : $#"
    echo "Start     : `date`"
    echo " "
    echo "--CMD------------------------------"
    echo "$3"
    
    if [ -n "$4" ]; then echo "$4"; fi
    if [ -n "$5" ]; then echo "$5"; fi
    if [ -n "$6" ]; then echo "$6"; fi
    if [ -n "$7" ]; then echo "$7"; fi
    if [ -n "$8" ]; then echo "$8"; fi
    
    echo "--END-CMD--------------------------"
    echo " "

    if [ "$2" = "EXEC" ]; then
        #
        # Run the commands
        #
        if [ "$1" = "OS" ]; then 
            $3
            if [ "$?" -ne "0" ]; then echo "SHELL $ERROR_STR"; exit 1; fi
        fi 

        if [ "$1" = "SQL" ]; then
            $ORACLE_HOME/bin/sqlplus / as sysdba << EOF
            WHENEVER OSERROR EXIT FAILURE ROLLBACK
            WHENEVER SQLERROR EXIT FAILURE ROLLBACK
            $3
            $4
            $5
            $6
            $7
            $8
            exit;
EOF
            if [ "$?" -ne "0" ]; then echo "SQLPLUS $ERROR_STR"; exit 1; fi
        fi 
 
        if [ "$1" = "RMAN" ]; then
            $ORACLE_HOME/bin/rman target=/ << EOF
            $3
            $4
            $5
            $6
            $7
            $8
            exit;
EOF
            if [ "$?" -ne "0" ]; then echo "RMAN $ERROR_STR"; exit 1; fi
        fi
    fi
    echo " "
    echo "Command run finished : `date`"
    echo " "

}

TEST_EXEC=$2
LOGFILE=$3
FULL_ROLLFORWARD=$4
OPEN_NOOPEN=$5
BACKUP_FILES_DIR=$6
RESTORE_SCRIPTS_DIR=$7
CONFIG_FILE=$8
DB_NAME=$9
FRA_DIR=${10}
MULTIPLEX1_DIR=${11}
MULTIPLEX2_DIR=${12}
DROP_NODROP=${13}
DB_FILE_CREATE_DIR=${14}

UPPER_DB_NAME=`echo $DB_NAME | tr  "[:lower:]" "[:upper:]"`
#
# Check cmd args
#
echo "Curent command : $0 $1 $2 $3 $4 $5 $6 $7 $8 $9 ${10} ${11} ${12} ${13} ${14}"
if [ "$FULL_ROLLFORWARD" = "ROLLFORWARD" ] && [ $# -eq 10 ]
then
    RMAN_TIDYUP=${10}
elif [ "$FULL_ROLLFORWARD" = "ROLLFORWARD" ] && [ $# -ne 10 ]
then
    echo "ROLLFORWARD mode selected"
    echo "Arg count : $#"
    echo "$ERROR_STR - Syntax : $0 ORACLE_SID TEST|EXEC LOGFILE FULL|ROLLFORWARD OPEN|NOOPEN BACKUP_FILES_DIR RESTORE_SCRIPTS_DIR CONFIG_FILE DB_NAME"
    exit 1
elif [ "$FULL_ROLLFORWARD" = "FULL" ] && [ $# -ne 14 ]
then
    echo "FULL rebuild mode selected"
    echo "Arg count : $#"
    echo "$ERROR_STR - Syntax : $0 ORACLE_SID TEST|EXEC LOGFILE FULL|ROLLFORWARD OPEN|NOOPEN BACKUP_FILES_DIR RESTORE_SCRIPTS_DIR CONFIG_FILE DB_NAME FRA_DIR MULTIPLEX1_DIR MULTIPLEX2_DIR DROP|NODROP NEW_DATAFILE_DIR"
    exit 1
fi

export ORACLE_SID=`echo $1 | tr  "[:upper:]" "[:lower:]"`

UPPER_SID=`echo $1 | tr  "[:lower:]" "[:upper:]"`
RMAN_CMD_FILE="$RESTORE_SCRIPTS_DIR/../rman_cmd_files/dbsync_`hostname`_${ORACLE_SID}_${FULL_ROLLFORWARD}.rcv"

MULTIPLEX1_WITH_SID_DIR="$MULTIPLEX1_DIR/$UPPER_SID"
MULTIPLEX2_WITH_SID_DIR="$MULTIPLEX2_DIR/$UPPER_SID"

NEW_CTL_FILES="'$MULTIPLEX1_WITH_SID_DIR/$ORACLE_SID.ctl'"

SMON="smon_$ORACLE_SID"
TEST=`ps -ef |grep $SMON|grep -v grep|wc -l`

if [ "$TEST" = 0 ]; then
    echo "SMON : $SMON is NOT running... $ERROR_STR"
    exit 2;
fi
#
# Set env
#
export ORACLE_HOME=`cat /etc/oratab|grep ^$ORACLE_SID:|cut -f2 -d':'`
PATH=$ORACLE_HOME/bin:$PATH
export PATH
NEW_DATAFILE_DIR="$DB_FILE_CREATE_DIR/$UPPER_SID/datafile"
LOGFILE_DIR1="$MULTIPLEX1_DIR/$UPPER_SID/onlinelog"
LOGFILE_DIR2="$MULTIPLEX2_DIR/$UPPER_SID/onlinelog"
#
# Basic parameters
#
echo " "
echo $LINE
echo Basic settings
echo $LINE
echo "Config file         : $CONFIG_FILE"
echo "Oracle SID          : $ORACLE_SID"
echo "Database Name       : $DB_NAME"
echo "Oracle Home         : $ORACLE_HOME"
echo "Backup files dir    : $BACKUP_FILES_DIR"
echo "DBsync script dir   : $RESTORE_SCRIPTS_DIR"
echo "RMAN files          : $RMAN_CMD_FILE"
echo "path                : $PATH"
echo "Test or Exec        : $TEST_EXEC"
echo "Logfile             : $LOGFILE"
echo "Full or Rollforward : $FULL_ROLLFORWARD"
echo "Open or NoOpen      : $OPEN_NOOPEN"
#
# Extra prameter needed for full restore
#
if [ "$FULL_ROLLFORWARD" = "FULL" ]
then
    echo $LINE
    echo Full Rebuild settings
    echo $LINE
    echo "multiplex1          : $MULTIPLEX1_DIR"
    echo "multiplex2          : $MULTIPLEX2_DIR"
    echo "fra dir             : $FRA_DIR"
    echo "db file create      : $DB_FILE_CREATE_DIR"
    echo "new datafile dir    : $NEW_DATAFILE_DIR"
    echo "new ctl file        : $NEW_CTL_FILES"
    echo "drop old db         : $DROP_NODROP"
fi

echo $LINE
echo " "
#
# Wait for any rsync processes to finish
#
msg 'Wait for any in-progress rsync copies of archivelogs, ignore backup archivelogs'
$RESTORE_SCRIPTS_DIR/wait_for_rsync_process_to_finish.sh $BACKUP_FILES_DIR _backup_archivelogs_
#
# Full backup to restore?
#
if [ "$FULL_ROLLFORWARD" = "FULL" ]; then
    #
    # Find control file
    #
    CONTROL_FILE=`ls -ltr $BACKUP_FILES_DIR/*controlfile* | tail -n1 | awk {'print $9'}`
    if [ -z "$CONTROL_FILE" ]; then echo "NO CONTROLFILE BACKUP : $BACKUP_DIR "; exit 5; fi

    if [ "$DROP_NODROP" = "DROP" ]; then
        #
        # Test a full open first
        #
        msg 'Test a open resetlogs, this checks online logs etc'
        run 'SQL' $TEST_EXEC "alter database open resetlogs;"
        run 'SQL' $TEST_EXEC "shutdown immediate;"
        #
        # Drop the database
        #
        msg 'Drop the database process'
        run 'SQL' $TEST_EXEC "startup mount exclusive;"
        run 'SQL' $TEST_EXEC "alter system enable restricted session;"
        run 'RMAN' $TEST_EXEC "drop database noprompt;"
    else
        #
        # Need to shut down
        #
        run 'SQL' $TEST_EXEC "shutdown abort;"
    fi
    #
    # Check and create directories if needed
    #
    msg 'Check required directories exist, create if they are not'
    create_dir_if_does_not_exist 'multiplex1 with SID' $MULTIPLEX1_WITH_SID_DIR
    create_dir_if_does_not_exist 'multiplex2 with SID' $MULTIPLEX2_WITH_SID_DIR
    create_dir_if_does_not_exist 'new datafile dir' $NEW_DATAFILE_DIR
    create_dir_if_does_not_exist 'fra dir' $FRA_DIR
    create_dir_if_does_not_exist 'logfile dir1' $LOGFILE_DIR1
    create_dir_if_does_not_exist 'logfile dir2' $LOGFILE_DIR2
    echo ''
    #
    # Need to delete arivelogs from the previous restore
    # these will cause the restore to fail
    #
    msg 'Clean up archive and online logs from previous database'
    run 'OS' $TEST_EXEC "rm -rf $FRA_DIR/$UPPER_SID/archivelog/*"
    #
    # Delete onlines
    #
    run 'OS' $TEST_EXEC "rm -f $LOGFILE_DIR1/*"
    run 'OS' $TEST_EXEC "rm -f $LOGFILE_DIR2/*"
    #
    # Start instance
    #
    msg 'Recreate the spfile'
    PFILE="$ORACLE_HOME/dbs/init${ORACLE_SID}.ora"
    run 'SQL' $TEST_EXEC "startup nomount pfile=$PFILE ;"
    #
    # If database was dropped then the spfile will be deleted
    # and controlfile drectory
    #

    #
    # Bounce to use spfile
    #
    run 'SQL' $TEST_EXEC "create spfile from pfile;"
    msg 'Bounce db to use the new spfile'
    run 'SQL' $TEST_EXEC "shutdown abort;"
    run 'SQL' $TEST_EXEC "startup nomount;"
    #
    # Set file locations in spfile, and bounce to take effect
    #
    msg 'Set the instance parameter'
    run 'SQL' $TEST_EXEC "alter system set control_files=$NEW_CTL_FILES scope=spfile;"
    run 'SQL' $TEST_EXEC "alter system set db_create_file_dest='$DB_FILE_CREATE_DIR' scope=spfile;"
    run 'SQL' $TEST_EXEC "alter system set db_create_online_log_dest_1='$MULTIPLEX1_DIR' scope=spfile;"
    run 'SQL' $TEST_EXEC "alter system set db_create_online_log_dest_2='$MULTIPLEX2_DIR' scope=spfile;"
    msg 'Move the database to nomount for the restore of the control file, the bounce will pickup the new parameters'
    run 'SQL' $TEST_EXEC "shutdown abort;"
    run 'SQL' $TEST_EXEC "startup nomount;"
    #
    # Restore controlfile and mount the db
    #
    msg 'Restore the control file found in the backup and mount'
    run 'RMAN' $TEST_EXEC \
        "restore controlfile from '$CONTROL_FILE';" \
        "alter database mount;"
    #
    # Move tempfile and redo locations
    #
    msg 'Move the tempfile and redo to new instance locations'
    run 'SQL' $TEST_EXEC \ "@$RESTORE_SCRIPTS_DIR/move_files.sql $TEST_EXEC $LOGFILE_DIR1 $LOGFILE_DIR2 $NEW_DATAFILE_DIR"
fi
#
# Open read only?
# - then Bounce to mount first
# - since db is probably open read only now
#
if [ "$OPEN_NOOPEN" = 'OPEN_READ_ONLY' ]; then
    run 'SQL' $TEST_EXEC "shutdown abort;"
    run 'SQL' $TEST_EXEC "startup mount;"
fi
#
# Wait for any rsync processes to finish
#
msg 'Wait for any in-progress archivelog copies'
msg 'this is the second check, just before we catalog new files'
$RESTORE_SCRIPTS_DIR/wait_for_rsync_process_to_finish.sh $BACKUP_FILES_DIR _backup_archivelogs_
#
# Catalog the new backup
#
msg 'Catalog new backup in the controlfile'
run 'RMAN' $TEST_EXEC \
    "catalog start with '$BACKUP_FILES_DIR/$UPPER_DB_NAME' noprompt;" \
    "delete noprompt expired backup;"
#
# Generate the rman commands
# this will find the latest archivelog
# and move the datafiles
#
# Needs to be run even in test to see the rman commands
#
msg 'Generate the rman commands'
run 'SQL' 'EXEC' "@$RESTORE_SCRIPTS_DIR/gen_rman_cmds.sql $FULL_ROLLFORWARD $OPEN_NOOPEN $NEW_DATAFILE_DIR $RMAN_CMD_FILE"
#
# run the rman script
#
msg 'Restore the database, then recover up latest redo'
run 'OS' $TEST_EXEC \
    "$ORACLE_HOME/bin/rman target=/ cmdfile=$RMAN_CMD_FILE"
    
if [ "$RMAN_TIDY_UP" = "RMAN_TIDY_UP" ]
then
    #
    # Tidy up backup files not needed
    #
    msg 'Crosscheck backups'
    run 'RMAN' $TEST_EXEC \
        "crosscheck backup;"

    msg 'Remove missing files from the catalog'
    run 'RMAN' $TEST_EXEC \
        "delete noprompt expired backup;"
    
    msg 'Crosscheck archivelogs'
    run 'RMAN' $TEST_EXEC \
        "crosscheck archivelog all;"
    
    msg 'Remove missing archivelogs from the catalog'
    run 'RMAN' $TEST_EXEC \
        "delete noprompt expired archivelog all;"
    
    msg 'Delete obsolete backups'
    run 'RMAN' $TEST_EXEC \
        "delete noprompt obsolete;"
        
fi

#
# Check the lag
#
msg 'Check the standby lag'
run 'SQL' $TEST_EXEC "@$RESTORE_SCRIPTS_DIR/standby_lag.sql"
