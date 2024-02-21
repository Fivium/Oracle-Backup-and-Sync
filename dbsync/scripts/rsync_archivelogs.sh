#!/bin/bash

CERT_LOCATION='<CERT_LOCATION>'
COPY_TO_SERVER='<COPY_TO_SERVER>'

echo "-----------"
echo "Rsync files"
echo "-----------"

if [ $# -lt 1 ]
then
    echo "Expected 1 args got $#"
    echo "Error - usage       : $0 <SID> <BOTH|ARCHIVELOGS|BACKUP_ARCHIVELOGS>"
    echo "Default copy option : BOTH"
    exit 1
fi

SID=${1}
COPY_OPTION=$2
if [ -z "${COPY_OPTION}" ]; then
    COPY_OPTION='BOTH'
fi

echo "SID         : $SID"
echo "COPY_OPTION : $COPY_OPTION"

LOG_TO_FILE="/oracle/backups/logs/rsync_${COPY_OPTION}_${SID}.log"

echo "LOG         : $LOG_TO_FILE"
echo ""

DAY_STR=`date +%Y-%m-%d`

function log_timestamp {
    TIME_STR=`date +%H:%M:%S`
    echo " " >> "$LOG_TO_FILE"
    echo "$1 ${DAY_STR} ${TIME_STR}" >> "$LOG_TO_FILE"
    echo " " >> "$LOG_TO_FILE"
}

function do_rsync {

    DESC="syncing files from $1 to ${COPY_TO_SERVER}:${2}"

    echo "$DESC" >> "$LOG_TO_FILE"

    DAY_RSYNC_RUN_COUNT=`grep "START $DAY_STR" "$LOG_TO_FILE" | wc -l`

    echo "RSYNC day run count : $DAY_RSYNC_RUN_COUNT" >> "$LOG_TO_FILE"

    rsync -avz --exclude='*.arc.gz' -e "ssh -i ${CERT_LOCATION}" --update $1 ${COPY_TO_SERVER}:${2} >> $LOG_TO_FILE 2>&1

    log_timestamp "Finished $DESC"
}
#
# Exit if backup already running
#
RUNNING=`ps -ef | grep "$0 $1 $2" | grep -v grep | wc -l`

if [ $RUNNING -gt 2 ]
then
    echo ""
    echo "Running count : $RUNNING, Script $0 $1 is running, time to exit!"
    exit 1
fi

log_timestamp START
#
# Sync archivelogs
#
SYNC_TO_DIR="/oracle/fra/${SID}/${SID}_archivelogs"

if [ "$COPY_OPTION" = 'ARCHIVELOGS' ] || [ "$COPY_OPTION" = 'BOTH' ]; then
    echo "Sync ARCHIVELOGS"
    do_rsync "/oracle/fra/${SID}/archivelog/*" "$SYNC_TO_DIR"
fi

if [ "$COPY_OPTION" = 'BACKUP_ARCHIVELOGS' ] || [ "$COPY_OPTION" = 'BOTH' ]; then
    #
    # Backup archivelogs
    #
    echo "Sync BACKUP_ARCHIVELOGS"
    THIS_HOST=`hostname`
    BASE_BACKUP_DIR="/oracle/backups/files/${SID}"
    echo "Backup base dir : $BASE_BACKUP_DIR"

    if [ -d "$BASE_BACKUP_DIR" ]; then
        echo "Backup base dir found"
    else
        BASE_BACKUP_DIR="${BASE_BACKUP_DIR}1"
        echo "Backup base dir NOT found"
        echo "Backup base dir changed to : $BASE_BACKUP_DIR"
    fi

    if [ -d "$BASE_BACKUP_DIR" ]; then
        SYNC_FROM="${BASE_BACKUP_DIR}/${THIS_HOST}/*_backup_archivelogs_*"
        do_rsync "$SYNC_FROM" "$SYNC_TO_DIR"
    else
        echo "New backup dir NOT found"
    fi

fi
#
# Trim logfile
#
TEMP_LOG_FILE="$LOG_TO_FILE.tail"
tail -n 10000 "$LOG_TO_FILE" > "$TEMP_LOG_FILE"
mv "$TEMP_LOG_FILE" "$LOG_TO_FILE"

