#!/bin/bash
#
# $Id: //Infrastructure/Database/scripts/dbsync/scripts/dbsync_ctl.sh#6 $ 
#
# T Dale 2014-01-31
# Database sync controling script
#
ORASID=$1
TEST_EXEC=$2
FULL_ROLLFORWARD=$3
OPEN_NOOPEN=$4
DROP_OR_NODROP=$5

UPPER_SID=`echo $1 | tr  "[:lower:]" "[:upper:]"`

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="$SCRIPTDIR/../config/`hostname`_$ORASID.sh"
echo ""
echo "Getting config from : $CONFIG_FILE"

if [ -f $CONFIG_FILE ]
then
    source $CONFIG_FILE;
else
    echo "ERROR - Can't find config file $CONFIG_FILE"
    exit 1

fi
#
# Check cmd args
#
if [ "$FULL_ROLLFORWARD" = "ROLLFORWARD" ] && [ $# -ne 4 ]
then
    echo "ROLLFORWARD mode selected"
    echo "ERROR - Syntax : $0 ORACLE_SID TEST|EXEC ROLLFORWARD OPEN|NOOPEN"
    exit 1
elif [ "$FULL_ROLLFORWARD" = "FULL" ] && [ $# -ne 5 ]
then
    echo "FULL REBUILD mode selected"
    echo "ERROR - Syntax : $0 ORACLE_SID TEST|EXEC FULL OPEN|NOOPEN DROP|NODROP"
    exit 1
fi

GET_DATE_STR="date +%Y_%m_%d_%H_%M_%S"
START_DATE=`$GET_DATE_STR`
STANDBY_SERVER=`hostname`

LOGFILE_PREFIX="dbsync"
LOGFILE_SUFFIX=".log"
LOGFILE_BASENAME="${LOGFILE_PREFIX}__${STANDBY_SERVER}__${ORASID}__${FULL_ROLLFORWARD}__${START_DATE}${LOGFILE_SUFFIX}"
LOGFILE="$LOGFILE_DIR/$LOGFILE_BASENAME"
echo "Logging to          : $LOGFILE"
echo "Start               : $START_DATE"
echo "Backup files dir    : $BACKUP_FILES_DIR"
echo ""
echo "Uncompress any tarballs"
#
# Look for tarballs
#
cd $BACKUP_FILES_DIR

TAR_BACKUP_FILES=$BACKUP_FILES_DIR/*.tgz
shopt -s nullglob
for f in $TAR_BACKUP_FILES
do
    echo "Extractiong $f file..."  
    ls -lh $f
    #
    # Parallel Unzip removing paths
    #
    tar -I pigz -xf $f -v --show-transformed --transform='s=.*/=='
    #
    # Success?
    #
    if [ $? -eq 0 ]; then
        echo ""
        echo "Delete old tarball"
        rm -v $f
    fi

done

echo ""
echo "Run dbsync, check log for more detail."
echo ""

if [ "$FULL_ROLLFORWARD" = "FULL" ]
then
    $RESTORE_SCRIPTS_DIR/dbsync.sh \
        $ORASID \
        $TEST_EXEC \
        $LOGFILE \
        $FULL_ROLLFORWARD \
        $OPEN_NOOPEN \
        $BACKUP_FILES_DIR \
        $RESTORE_SCRIPTS_DIR \
        $CONFIG_FILE \
        $FRA_DIR \
        $MULTIPLEX1_DIR \
        $MULTIPLEX2_DIR \
        $DROP_OR_NODROP \
        $NEW_DATAFILE_DIR > $LOGFILE 2>&1
elif [ "$FULL_ROLLFORWARD" = "ROLLFORWARD" ]
then
    $RESTORE_SCRIPTS_DIR/dbsync.sh \
        $ORASID \
        $TEST_EXEC \
        $LOGFILE \
        $FULL_ROLLFORWARD \
        $OPEN_NOOPEN \
        $BACKUP_FILES_DIR \
        $RESTORE_SCRIPTS_DIR \
        $CONFIG_FILE > $LOGFILE 2>&1
else
  echo "Error FULL or ROLLFORWARD mode must be selected"
fi

#
# DB NAME 
# - This is hack need todo properly
# - Need to get this from the config file
#
SID_LENGTH=${#ORASID}
DB_NAME_LENGTH=$(($SID_LENGTH-4))
DB_NAME=${ORASID:0:DB_NAME_LENGTH}

END_DATE=`$GET_DATE_STR`
SYNC_LOG_DETAILS_FILE="${LOGFILE_DIR}/dbsync_details.txt"

if [ -z "$DROP_OR_NODROP" ]
then
    DROP_OR_NODROP='NA'
fi

echo "Finish              : $END_DATE"
echo "${LOGFILE_BASENAME},${STANDBY_SERVER},${DB_NAME},${ORASID},${FULL_ROLLFORWARD},${START_DATE},${END_DATE},${OPEN_NOOPEN},${CONFIG_FILE},${DROP_OR_NODROP}" >> "$SYNC_LOG_DETAILS_FILE"

#
# Delete old logs from the log detail file
#

echo ""
echo "Housekeep logfiles"
echo ""
find $LOGFILE_DIR -name "${LOGFILE_PREFIX}*${LOGFILE_SUFFIX}" -mtime +0 -print -delete
echo ""
echo "Tidy up the external table access logs"
echo ""
find "$LOGFILE_DIR" -name "DBSYNC_LOGS_*.log" -print -delete
find "$LOGFILE_DIR" -name "sed*" -print -delete

PRIMARY_LOGFILE_DIR="${PRIMARY_LOGFILE_BASE_DIR}/${STANDBY_SERVER}__${ORASID}"

echo ""
echo "Sync logs back"
echo "- Primary host             : $PRIMARY_HOST"
echo "- Primary logfile base dir : $PRIMARY_LOGFILE_BASE_DIR"
echo "- Primary logfile dir      : $PRIMARY_LOGFILE_DIR"
echo "- Standby logfile dir      : $LOGFILE_DIR"
echo ""

#
# Varibles set?
#
if [ -z "$PRIMARY_HOST" ] || [ -z "$PRIMARY_LOGFILE_BASE_DIR" ] || [ -z "$LOGFILE_DIR" ] 
then 
    echo "--"
    echo "-- DONT KNOW WHERE TO SYNC LOGS BACK TO?"
    echo "--"
else
    rsync -n -avz $LOGFILE_DIR/* oracle@$PRIMARY_HOST:$PRIMARY_LOGFILE_DIR
fi

