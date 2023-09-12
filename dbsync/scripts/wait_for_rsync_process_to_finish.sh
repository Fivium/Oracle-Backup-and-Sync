#!/bin/bash

SLEEP_SECONDS=5

if [ $# -ne 1 ]
then
    echo "Wrong argument count, Usage: wait_for_rsync_process_to_finish.sh <SYNC_TO_TO_DIR>"
    exit 1
fi

DESTINATION_PATH=$1
#
# Check path does not have trailing /
# we will use this to check the rsync is just to this directory
#
DESTINATION_PATH_LAST_CHAR=${DESTINATION_PATH: -1}

if [ $DESTINATION_PATH_LAST_CHAR = '/' ]; then
    echo "Please remove trailing / from  <SYNC_TO_TO_DIR>"
    exit 3
fi

echo ""
echo "Wait for rsync process for this databases archivelogs to finish"

function SET_RSYNC_PROCESS_COUNT()
{
    echo ""
    date
    echo ""
    #
    # The grep -v is remove processes syncing to further subdirectories
    # eg $DESTINATION_PATH/archivelog_backups
    #
    CHECK_PROCESS_CMD="ps -ef | grep 'rsync --server' | grep $DESTINATION_PATH | grep -v '${DESTINATION_PATH}.*/[a-zA-Z0-9]\+'"
    RSYNC_PROCESS_COUNT=$(eval "$CHECK_PROCESS_CMD | wc -l")
    eval $CHECK_PROCESS_CMD
}

SET_RSYNC_PROCESS_COUNT

while [ $RSYNC_PROCESS_COUNT -gt 0 ]
do
   echo ""
   echo "rsync to $DESTINATION_PATH processes running : $RSYNC_PROCESS_COUNT"
   echo ""
   ls -ltrha ${DESTINATION_PATH} | awk '$9 ~ /^\.[a-zA-Z0-9]/'
   echo ""
   echo "wait a $SLEEP_SECONDS seconds for this to finish and then check again..."
   sleep $SLEEP_SECONDS
   SET_RSYNC_PROCESS_COUNT
done

echo "No processes running the rsync for destination : $DESTINATION_PATH"
echo ""
