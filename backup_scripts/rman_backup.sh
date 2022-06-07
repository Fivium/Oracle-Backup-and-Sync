#!/bin/bash

#
# T Dale
#

ARCH='ARCHIVELOGS_ONLY'
FULL='FULL_BACKUP'
CROSSCHECK='CROSSCHECK'
DEL_ALL_BEFORE='DEL_ALL_BK_FIRST'
DEL_OBSOLETE='DELETE_OBSOLETE'
FOR_STANDBY='FOR_STANDBY'
NOT_FOR_STANDBY='NOT_FOR_STANDBY'
SYNC='SYNC'
NOSYNC='NOSYNC'
COMPRESS='COMPRESS'
NOCOMPRESS='NOCOMPRESS'
SKIP_TRUE='TRUE'
SKIP_FALSE='FALSE'
ARGS=8

RMAN_POC_STR='NUMBER OF RMAN PROCESSES'
SCRIPT_ERROR_STR="ERROR - Syntax : $0 <ORACLE_SID> <$FULL|$ARCH|$CROSSCHECK> <$RMAN_POC_STR> <BACKUP DIR BASE PATH> <$DEL_ALL_BEFORE|$DEL_OBSOLETE> <$FOR_STANDBY|$NOT_FOR_STANDBY> <COMPRESS|NOCOMPRESS> <SKIP_BACKUP> $SKIP_TRUE | $SKIP_FALSE "
#
# Params provides
#
ORACLE_SID=$1
BACKUP_TYPE=$2
RMAN_PROCESSES=$3
BASE_PATH=$4
DEL_POLICY=$5
STANDBY=$6
COMPRESSION=$7
SKIP=$8

LINE="--------------------"
echo $LINE
echo "Args provided"
echo $LINE
echo "Oracle sid     : $ORACLE_SID"
echo "Backup Type    : $BACKUP_TYPE"
echo "RMAN Processes : $RMAN_PROCESSES"  
echo "Base path      : $BASE_PATH"
echo "Delete Policy  : $DEL_POLICY"
echo "For standby    : $STANDBY"
echo "Compression    : $COMPRESSION"
echo "Skipping backup: $SKIP"
echo ""


#
# Exit if backup already running
#
RUNNING=`ps -ef | grep "$0" | grep -v grep | wc -l`

if [ $RUNNING -gt 2 ]
then
    echo "`ps -ef | grep $0 | grep -v grep`"
    echo "Running count : $RUNNING, Script $0 is running, time to exit!"
    exit 1
fi

#
# Check correct number of cmd args
#

if [ $# -ne $ARGS ]
then
    echo "Expected $ARGS args got $#"
    echo $SCRIPT_ERROR_STR
    exit 1
fi

#
# Check base path looks ok
#
if [ -d "$BASE_PATH" ]
then
    echo "Base path exists"
else
    echo "<BACKUP DIR BASE PATH> : $BASE_PATH - is not correct"
    echo $SCRIPT_ERROR_STR
    exit 2
fi

if [ "$DEL_POLICY" = "$DEL_ALL_BEFORE" ]||[ "$DEL_POLICY" = "$DEL_OBSOLETE" ]
then
    echo "Backup policy pass"
else
    echo "Delete polict wrong : $DEL_POLICY"
    echo $SCRIPT_ERROR_STR
    exit 3
fi

if [ "$BACKUP_TYPE" = "$ARCH" ]||[ "$BACKUP_TYPE" = "$FULL" ]||[ "$BACKUP_TYPE" = "$CROSSCHECK" ]
then
    echo "Backup Type pass"
else
    echo $SCRIPT_ERROR_STR
    exit 3
fi

if [ ! $(echo "$RMAN_PROCESSES" | grep -E "^[0-9]+$") ]
then
    echo "ERROR - Rman process : $RMAN_PROCESSES is not a valid integer."
    echo $SCRIPT_ERROR_STR
    exit 4
fi

export ORACLE_SID=$1
export ORACLE_HOME=`cat /etc/oratab|grep ^$ORACLE_SID:|cut -f2 -d':'`
PATH=$ORACLE_HOME/bin:$PATH
export PATH
HOSTNAME=`hostname`

#tr '[a-z]' '[A-Z]' < $ORACLE_SID

echo "oracle home : $ORACLE_HOME"
echo "path        : $PATH"

BASE_RMAN_CMD_FILE="${BASE_PATH}/scripts/rman/rman_backup_${HOSTNAME}_${ORACLE_SID}"
UPPER_SID=`echo $ORACLE_SID | tr  "[:lower:]" "[:upper:]"`
BACKUP_DIR="${BASE_PATH}/files/${UPPER_SID}/${HOSTNAME}"
BASE_FORMAT="${BACKUP_DIR}/%d_backup"
TAIL_FORMAT='%T_%U_set_%s'
DATE_STR=`date +'%Y_%m_%d-h%H-m%M'`

#
# Create backup dir if it's not there
#
if [ ! -d $BACKUP_DIR ]; then
    echo "Creating dir : $BACKUP_DIR"
    mkdir -p $BACKUP_DIR
fi

if [ "$STANDBY" = "$FOR_STANDBY" ]
then
    CF_CTL_STR="backup device type disk format '${BASE_FORMAT}_cf_standby__${TAIL_FORMAT}' current controlfile for standby tag='cf_standby_${DATE_STR}';"
    #
    # Don't delete the archivelogs data gaurd is happier with them around
    #
    DELETE_ARCH=""
else
    DELETE_ARCH="delete input"
fi

if [ "$COMPRESSION" = "$COMPRESS" ]; then
    echo "turning on compression"
    RMAN_COMPRESSION="compressed "
else
    echo "turning off compression"
    RMAN_COMPRESSION=""
fi

CONF_PARALLELISM_STR="configure device type disk parallelism ${RMAN_PROCESSES} backup type to ${RMAN_COMPRESSION}backupset;"
BACKUP_ARCHIVELOGS_STR="backup device type disk format '${BASE_FORMAT}_archivelogs_${TAIL_FORMAT}' archivelog all $DELETE_ARCH tag='archivelogs_${DATE_STR}';"

if [ "$DEL_POLICY" =  "$DEL_ALL_BEFORE" ]
then
    echo "Delete old backup first"
    DELETE_BK_STR="delete noprompt backup;"
    DELETE_ARCH_STR="delete noprompt archivelog all;"
fi

if [ $BACKUP_TYPE = $CROSSCHECK ]
then
    RMAN_CMD_FILE="${BASE_RMAN_CMD_FILE}_${CROSSCHECK}.rcv"
    cat <<END_CMD>$RMAN_CMD_FILE
run{
crosscheck backup;
crosscheck archivelog all;
delete noprompt expired backup;
delete noprompt expired archivelog all;
}
END_CMD

elif [ $BACKUP_TYPE = $ARCH ]

then
    RMAN_CMD_FILE="${BASE_RMAN_CMD_FILE}_${ARCH}.rcv"
    cat <<END_CMD>$RMAN_CMD_FILE
run{
$CONF_PARALLELISM_STR
$BACKUP_ARCHIVELOGS_STR
}
list backup summary;
END_CMD

else

    RMAN_CMD_FILE="${BASE_RMAN_CMD_FILE}_${FULL}.rcv"
    cat <<END_CMD>$RMAN_CMD_FILE
run{
crosscheck backup;
crosscheck archivelog all;
delete noprompt expired backup;
delete noprompt expired archivelog all;
$DELETE_BK_STR
$DELETE_ARCH_STR
$CONF_PARALLELISM_STR
show all;
backup device type disk format '${BASE_FORMAT}_database_${TAIL_FORMAT}' database tag='datafiles_${DATE_STR}';
$CF_CTL_STR
$BACKUP_ARCHIVELOGS_STR
delete noprompt obsolete;
backup device type disk format '${BASE_FORMAT}_controlfile_${TAIL_FORMAT}' current controlfile tag='controlfile_${DATE_STR}';
}
run{
backup device type disk format '${BASE_FORMAT}_spfile_${TAIL_FORMAT}' spfile tag='spfile_${DATE_STR}';
}
list backup summary;
END_CMD

fi

#
# Do the backup for dbs that does not have TRUE on the skip parameter
#

if [ $SKIP = $SKIP_TRUE ]
then
   echo "Skipping backup of :  $ORACLE_SID"
   echo "Because aint nobody got time"

else

$ORACLE_HOME/bin/rman target=/ cmdfile=$RMAN_CMD_FILE

fi
#
# Just list the backup dir
#
ls -ltrh $BACKUP_DIR
