#!/bin/bash

# - this is better than doing it via backup
# - add parameter db
#     archive_lag_target = 180 ( for 3 minute max lag )
# - add crontab
#     * * * * * <SCRIPT_DIR>/rsync_archivelogs.sh
#
echo "Rsync files"

LOG_TO_FILE='<LOG_DIR>/rsync_achivelogs.log'
CERT_LOCATION='<CERT_FILE>'

function log_timestamp {
    echo " " >> "$LOG_TO_FILE"
    echo `date` >> "$LOG_TO_FILE"
    echo " " >> "$LOG_TO_FILE"
}

COPY_TO_SERVER='<STANDBY_SERVER>'

function do_rsync {

    echo "syncing files from $1 to ${COPY_TO_SERVER}:${2}" >> "$LOG_TO_FILE"

    rsync -av -e "ssh -i ${CERT_LOCATION}" --update --progress $1 ${COPY_TO_SERVER}:${2} >> $LOG_TO_FILE 2>&1

    log_timestamp

}
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

log_timestamp
#
# Sync archivelogs
#
SYNC_TO_DIR='<REMOTE_BACKUP_DIR>'
do_rsync '<FRA_PATH>/archivelog/*' "$SYNC_TO_DIR"
do_rsync '<BACKUP_PATH>/<SID>_backup_archivelogs_*' "$SYNC_TO_DIR"

log_timestamp

#
# Trim logfile
#
TEMP_LOG_FILE="$LOG_TO_FILE.head"
head -n 1000 "$LOG_TO_FILE" > "$TEMP_LOG_FILE"
mv "$TEMP_LOG_FILE" "$LOG_TO_FILE"
