#!/bin/bash

# - This is better than doing it via backup
# - Add parameter db
#     archive_lag_target = 180 ( for 3 minute max lag )
# - Add crontab
#     * * * * * <SCRIPT_DIR>/rsync_archivelogs.sh
# - Set in RMAN ( this will keep a copy in the FRA for rsync to standby )
#     CONFIGURE ARCHIVELOG DELETION POLICY TO BACKED UP 2 TIMES TO DISK;

echo "Rsync files"

LOG_TO_FILE='<LOG_DIR>/rsync_achivelogs.log'
CERT_LOCATION='<CERT_FILE>'
DAY_STR=`date +%Y-%m-%d`

function log_timestamp {
    TIME_STR=`date +%H:%M:%S`
    echo " " >> "$LOG_TO_FILE"
    echo "$1 ${DAY_STR} ${TIME_STR}" >> "$LOG_TO_FILE"
    echo " " >> "$LOG_TO_FILE"
}

COPY_TO_SERVER='<STANDBY_SERVER>'

function do_rsync {

    DESC="syncing files from $1 to ${COPY_TO_SERVER}:${2}"
    
    echo "$DESC" >> "$LOG_TO_FILE"

    DAY_RSYNC_RUN_COUNT=`grep "START $DAY_STR" "$LOG_TO_FILE" | wc -l`

    echo "RSYNC day run count : $DAY_RSYNC_RUN_COUNT" >> "$LOG_TO_FILE"
    #
    # We want to do a checksum transfer
    # at the start of the day
    #
    if [ "$DAY_RSYNC_RUN_COUNT" -eq "1" ]
    then
        echo "RSYNC with checksum" >> "$LOG_TO_FILE"
        echo "If there are a lot of archivelogs, then this may take a long time" >> "$LOG_TO_FILE"
        echo "You may want to comment this out if it causes too much lag" >> "$LOG_TO_FILE"
        rsync -avz -e "ssh -i ${CERT_LOCATION}" --checksum --stats --update $1 ${COPY_TO_SERVER}:${2} >> $LOG_TO_FILE 2>&1
    else
        rsync -avz -e "ssh -i ${CERT_LOCATION}"                    --update $1 ${COPY_TO_SERVER}:${2} >> $LOG_TO_FILE 2>&1
    fi

    log_timestamp "Finished $DESC"
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

log_timestamp START
#
# Sync archivelogs
#
SYNC_TO_DIR='<REMOTE_BACKUP_DIR>'
do_rsync '<FRA_PATH>/archivelog/*' "$SYNC_TO_DIR"
#
# Sync archivelog backups
#
do_rsync '<BACKUP_PATH>/<SID>_backup_archivelogs_*' "${SYNC_TO_DIR}/archivelog_backups"
#
# Trim logfile
#
TEMP_LOG_FILE="$LOG_TO_FILE.tail"
tail -n 10000 "$LOG_TO_FILE" > "$TEMP_LOG_FILE"
mv "$TEMP_LOG_FILE" "$LOG_TO_FILE"
