#!/bin/sh

#
# rsync the archivelogs
# - this is better than doing it via backup
# - add parameter db 
#     archive_lag_target = 180 ( for 3 minute max lag )
# - add crontab 
#     * * * * * <SCRIPT_DIR>/rsync_archivelogs.sh
#

LOG_TO_FILE='<LOG_FILE>'

function log_timestamp {
    echo " " >> "$LOG_TO_FILE"
    echo `date` >> "$LOG_TO_FILE"
    echo " " >> "$LOG_TO_FILE"
}

log_timestamp
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


COPY_TO_SERVER='<REMOTE_SERVER>'

#
# Sync archivelogs
#
FILES_TO_COPY='<FRA_DIR>/archivelog/*'
COPY_TO_DIR='<REMOTE_BACKUP_DIR>'

echo "syncing files from $FILES_TO_COPY to ${COPY_TO_SERVER}:${COPY_TO_DIR}" >> "$LOG_TO_FILE"
rsync -av -e "ssh -i <CERT_LOCATION>" --update $FILES_TO_COPY $COPY_TO_SERVER:$COPY_TO_DIR >> $LOG_TO_FILE 2>&1

#
# Sync backups of archivelogs
#
FILES_TO_COPY='<BACKUP_DIR>/<SID>_backup_archivelogs_*'
echo "syncing files from $FILES_TO_COPY to ${COPY_TO_SERVER}:${COPY_TO_DIR}" >> "$LOG_TO_FILE"
rsync -av -e "ssh -i /home/oracle/.ssh/ecase-aws-oracle.pem" --update $FILES_TO_COPY $COPY_TO_SERVER:$COPY_TO_DIR >> $LOG_TO_FILE 2>&1

log_timestamp

TEMP_LOG_FILE="$LOG_TO_FILE.head"
head -n 1000 "$LOG_TO_FILE" > "$TEMP_LOG_FILE"
mv "$TEMP_LOG_FILE" "$LOG_TO_FILE"
