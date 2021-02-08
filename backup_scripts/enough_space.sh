#!/bin/bash

if [ $# -ne 2 ]
then
    echo "Wrong argument count, Usage:  enough_space.sh <ORACLE_SID> <BACKUP_TO_DIR>"
    exit 1
fi

export ORACLE_SID=$1
export ORACLE_HOME=`cat /etc/oratab|grep ^$ORACLE_SID:|cut -f2 -d':'`
export PATH=$ORACLE_HOME/bin:$PATH
#
# List of current backup files
#
CURRENT_BACKUP_FILES=$(sqlplus -S / as sysdba << EOF
  set head off
  set feedback off
  set pagesize 0
  set linesize 300
  SELECT fname FROM V\$BACKUP_FILES WHERE device_type='DISK' AND BS_INCR_TYPE='FULL' AND COMPLETION_TIME > SYSDATE - 30/24;
  exit
EOF
)
#
# Get size of last backup on disk
#
LAST_BACKUP_SIZE=0
LAST_BACKUP_SIZE_COMPRESSED=0

for BACKUP_FILE in  $CURRENT_BACKUP_FILES
do
  BACKUP_FILE_SIZE_ON_DISK=`du --bytes $BACKUP_FILE | awk '{print $1}'`
  BACKUP_FILE_SIZE_ON_DISK_COMPRESSED=`du --block-size=1 $BACKUP_FILE | awk '{print $1}'`
  LAST_BACKUP_SIZE=$(( $LAST_BACKUP_SIZE+$BACKUP_FILE_SIZE_ON_DISK ))
  LAST_BACKUP_SIZE_COMPRESSED=$(( $LAST_BACKUP_SIZE_COMPRESSED+$BACKUP_FILE_SIZE_ON_DISK_COMPRESSED ))
done
#
# Get the current size of the database
#
BACKUP_DIR=$2
DATABASE_SIZE_BYTES=$(sqlplus -S / as sysdba << EOF
  set head off
  set feedback off
  set pagesize 0
  set linesize 300
  select TO_CHAR(SUM(bytes)) FROM v\$datafile;
  exit
EOF
)
#
# Do we have a last backup on the filesystem to use for space check?
#
if [ "$LAST_BACKUP_SIZE_COMPRESSED" -gt 0 ]
then
  #
  # Use the compressed file system size
  # if its uncompressed, this value will also be correct
  #
  SPACE_REQUIRED="$LAST_BACKUP_SIZE_COMPRESSED"
else
  #
  # Check if there is enough room for the current size of the database
  #
  SPACE_REQUIRED="$DATABASE_SIZE_BYTES"
fi
# 
# Safety buffer is 20%
#
BUFFER_SIZE=$(( ${SPACE_REQUIRED}*20/100 ))
DEST_DIR=$BACKUP_DIR
## Get available space in DEST_DIR
SPACE_AVAILABLE=$(df $DEST_DIR -B1 -P | awk '{print $2}' | sed -e /1-blocks/d)
## Add buffer size
SPACE_REQUIRED_PLUS_BUFFER=$(($SPACE_REQUIRED+$BUFFER_SIZE))
DELTA=$(($SPACE_AVAILABLE-$SPACE_REQUIRED_PLUS_BUFFER))
## Details
echo "--------------------"
echo "Database : "$ORACLE_SID
echo "--------------------"
echo "All sizes in bytes"
printf "Last backup size on disk            : %16s\n" "$LAST_BACKUP_SIZE"
printf "Last backup size on disk compressed : %16s\n" "$LAST_BACKUP_SIZE_COMPRESSED"
printf "current database size               : %16s\n" "$DATABASE_SIZE_BYTES"
printf "space required                      : %16s\n" "$SPACE_REQUIRED"
printf "20 Percent buffer                   : %16s\n" "$BUFFER_SIZE"
printf "space required with buffer          : %16s\n" "$SPACE_REQUIRED_PLUS_BUFFER"
printf "space available                     : %16s\n" "$SPACE_AVAILABLE"
printf "free space after backup             : %16s\n" "$DELTA"
## Is there enough space available?
if (( $DELTA > 0 )); then
    echo "Space is available"
    exit 0
else
    echo "Space not available"
    exit 1
fi
