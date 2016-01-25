#!/bin/sh
#
# $Id: //Infrastructure/GitHub/Database/backup_and_sync/backup_scripts/oracle_log_purge.sh#1 $
#
# T Dale 2014-02-24
# Oracle log purging and zipping
#

if [ $# -ne 2 ]
then
    echo "ERROR - Syntax : $0 ORACLE_SID MINS_TO_KEEP"
    exit 1
fi

function zip_and_move {
    #
    # Do we have a file to op on
    #
    FILE_NAME=$1
    if [ -f "$FILE_NAME" ] && [ -n "$FILE_NAME" ]; then
    echo "GZIP : $FILE_NAME"
    gzip $FILE_NAME
    ARCH_FILE_NAME="${FILE_NAME}_`date +%Y_%m_%d_%H_%M_%S`.gz"
    echo "MOVE : ${FILE_NAME}.gz $ARCH_FILE_NAME"
    mv ${FILE_NAME}.gz $ARCH_FILE_NAME
    ls -lh $ARCH_FILE_NAME
fi

}

ORACLE_SID=$1
MINS_TO_KEEP=$2
LISTNER_LOG_MAX_SIZE="1M"
ALERT_LOG_MAX_SIZE="1M"

export ORACLE_HOME=`cat /etc/oratab|grep ^$ORACLE_SID:|cut -f2 -d':'`
export PATH=$ORACLE_HOME/bin:$PATH

ADR_BASE=`adrci exec="show base" | awk '{gsub(/"/,"",$NF); print $NF}'`
if [ ! -d "$ADR_BASE" ]; then
    echo "ERROR - ADR dir '$ADR_BASE' does not exist!"
    exit 2
fi

function file_info {
    DIAG_PATH=$ADR_BASE/$1
    du -sh $DIAG_PATH | awk '{print "File size  : "$1}'
    find $DIAG_PATH -type f | wc -l | awk '{print "File count : "$1}'
}

LINE='----------------------------------------'
echo ""
echo "Purge old oracle trace/log files older than $MINS_TO_KEEP minutes"
echo "ADR BASE : $ADR_BASE"
echo ""

echo "Zip the listener log if its bigger than $LISTNER_LOG_MAX_SIZE"
BIG_LISTENER_LOG=`find $ADR_BASE/diag -size +$LISTNER_LOG_MAX_SIZE -name listener.log`
zip_and_move $BIG_LISTENER_LOG
echo ""
echo "Zip the alert log first if its bigger than $ALERT_LOG_MAX_SIZE"
BIG_ALERT_LOG=`find $ADR_BASE/diag -size +$ALERT_LOG_MAX_SIZE -name alert_${ORACLE_SID}.log`
zip_and_move $BIG_ALERT_LOG
echo ""

adrci exec="show homes" |grep -v : | while read HOMEPATH
do
  echo ""
  echo $LINE
  echo "Diag Home : $ADR_BASE/$HOMEPATH"
  echo $LINE
  file_info $HOMEPATH
  echo "Purge..."
  adrci exec="set homepath $HOMEPATH;purge -age $MINS_TO_KEEP"
  file_info $HOMEPATH
done
