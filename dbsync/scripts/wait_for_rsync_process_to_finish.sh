#!/bin/bash

if [ $# -lt 1 ]
then
    echo "Wrong argument count, Usage: wait_for_rsync_process_to_finish.sh <SYNC_TO_TO_DIR> [EXCLUDE]"
    exit 1
fi

SLEEP_SECONDS=5
DESTINATION_PATH=$1
EXCLUDE=$2
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
echo "Wait for rsync process to $DESTINATION_PATH to finish"
if [ -n "$EXCLUDE" ]; then
    echo "don't wait for any files with '${EXCLUDE}' in the filename and path"
fi

function SET_RSYNC_PROCESS_COUNT()
{
    echo ""
    date
    echo ""
    #
    # CMD to check for the rsync process running and syncing to path
    #
    CHECK_PROCESS_CMD="ps -ef | grep 'rsync --server' | grep $DESTINATION_PATH"
    RSYNC_PROCESS_COUNT=$(eval "$CHECK_PROCESS_CMD | wc -l")
    eval $CHECK_PROCESS_CMD
}

SET_RSYNC_PROCESS_COUNT

while [ $RSYNC_PROCESS_COUNT -gt 0 ]
do
   echo ""
   echo "rsync to $DESTINATION_PATH processes running : $RSYNC_PROCESS_COUNT"
   echo ""
   find ${DESTINATION_PATH}* -type f -iname ".*" -ls | awk '{print $7" bytes "$11}'
   echo ""
   #
   # Do we have any excludes?
   #
   if [ -n "$EXCLUDE" ]; then
       echo ""
       echo "EXCLUDE : $EXCLUDE"
       echo ""
       find ${DESTINATION_PATH}* -type f -name "\.*${EXCLUDE}*" -mmin -10
       echo ""
   fi
   #
   # Sleep a few secons
   #
   echo "wait $SLEEP_SECONDS seconds for this to finish and then check again..."
   sleep $SLEEP_SECONDS
   SET_RSYNC_PROCESS_COUNT
done

echo "No processes running the rsync for destination : $DESTINATION_PATH"
echo ""
