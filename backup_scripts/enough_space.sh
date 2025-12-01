#!/bin/bash

PCT_FREE_BUFFER_DEFAULT=5

if [[ $# -ne 2 && $# -ne 3 ]]; then
    echo "Wrong argument count, Usage:  enough_space.sh <ORACLE_SID> <BACKUP_TO_DIR> [% Free Buffer (default: ${PCT_FREE_BUFFER_DEFAULT})]"
    exit 1
fi

PCT_FREE_BUFFER=$3
if [[ -z "${PCT_FREE_BUFFER}" ]]; then
  PCT_FREE_BUFFER=$PCT_FREE_BUFFER_DEFAULT
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
# Archivelog sizes
#
ARCHIVELOG_SIZE_BYTES=$(sqlplus -S / as sysdba << EOF
  set head off
  set feedback off
  set pagesize 0
  set linesize 300
  SELECT TO_CHAR(SUM(blocks*block_size)) archivelogs_size_bytes FROM V\$archived_log l WHERE deleted = 'NO' AND standby_dest = 'NO';
  exit
EOF
)
#
# Do we have a last backup on the filesystem to use for space check?
#
#if [ "$LAST_BACKUP_SIZE_COMPRESSED" -gt 0 ]
#then
  #
  # Use the compressed file system size to work out expected compression
  # if its uncompressed, this value will also be correct
  #
#  COMPRESSION_PERCENT=$(( ${LAST_BACKUP_SIZE_COMPRESSED}*100/${LAST_BACKUP_SIZE} ))

#else
  #
  # Set to a guess
  #
  #COMPRESSION_PERCENT=20
#fi

#
# Just set a default, best guess, but we don't use os compression anymore
#
COMPRESSION_PERCENT=100
#
# Check if there is enough room for the current size of the database
# and archivelogs
#
SPACE_REQUIRED=$(( $DATABASE_SIZE_BYTES + $ARCHIVELOG_SIZE_BYTES ))
#
# Space with compression
#
SPACE_REQUIRED_WITH_COMPRESSION=$(( ${SPACE_REQUIRED}*${COMPRESSION_PERCENT}/100 ))
#
# Safety buffer 
#
BUFFER_SIZE=$(( ${SPACE_REQUIRED_WITH_COMPRESSION}*${PCT_FREE_BUFFER}/100 ))
DEST_DIR=$BACKUP_DIR
## Get available space in DEST_DIR
SPACE_AVAILABLE=$(df $DEST_DIR -B1 -P | awk '{print $4}' | sed -e /Available/d)
## Add buffer size
SPACE_REQUIRED_PLUS_BUFFER=$(( ${SPACE_REQUIRED_WITH_COMPRESSION}+${BUFFER_SIZE} ))
DELTA=$(($SPACE_AVAILABLE-$SPACE_REQUIRED_PLUS_BUFFER))
## Details
bytes_to_human_readable() {

    local neg_sym='' i=${1:-0} d="" s=0 S=("Bytes" "KiB" "MiB" "GiB" "TiB" "PiB" "EiB" "YiB" "ZiB")

    if (( i < 0 )); then
        i=$(($1 * -1))
        neg_sym='-'
    fi

    while ((i > 1024 && s < ${#S[@]}-1)); do
        printf -v d ".%02d" $((i % 1024 * 100 / 1024))
        i=$((i / 1024))
        s=$((s + 1))
    done
    SIZE_HR="$neg_sym$i$d ${S[$s]}"
    printf "$2 %11s\n" "$SIZE_HR"

}

## Info

echo "--------------------"
echo "Database : "$ORACLE_SID
echo "--------------------"
bytes_to_human_readable $LAST_BACKUP_SIZE                "Last backup size on disk            : "
bytes_to_human_readable $LAST_BACKUP_SIZE_COMPRESSED     "Last backup size on disk compressed : "
printf "Last backup compression percent     : %12s\n" "$COMPRESSION_PERCENT"
bytes_to_human_readable $DATABASE_SIZE_BYTES             "Current database size               : "
bytes_to_human_readable $ARCHIVELOG_SIZE_BYTES           "Archivelog size                     : "
bytes_to_human_readable $SPACE_REQUIRED                  "Space required                      : "
bytes_to_human_readable $SPACE_REQUIRED_WITH_COMPRESSION "Space required with compression     : "
printf "Buffer Percent                      : %12s\n" "$PCT_FREE_BUFFER"
bytes_to_human_readable $BUFFER_SIZE                     "Buffer Size                         : "
bytes_to_human_readable $SPACE_REQUIRED_PLUS_BUFFER      "Space required with buffer          : "
bytes_to_human_readable $SPACE_AVAILABLE                 "Space available                     : "
if [[ $DELTA -lt 0 ]]; then
    EXTRA_BYTES_NEEDED=$(( DELTA * -1 ))
    bytes_to_human_readable $EXTRA_BYTES_NEEDED                           "Extra space needed                  : "
else
    bytes_to_human_readable $DELTA                           "Free space after backup             : "
fi
#
# Save info in database for alerts
#
sqlplus -S / as sysdba << EOF
DROP TABLE dbamgr.backup_size_info
/
CREATE TABLE dbamgr.backup_size_info AS (
  SELECT
    SYSDATE check_datetime
  , $DATABASE_SIZE_BYTES datafile_size_bytes
  , $ARCHIVELOG_SIZE_BYTES archivelog_size_bytes
  , $SPACE_REQUIRED_PLUS_BUFFER space_required_with_buffer_bytes
  , $SPACE_AVAILABLE backup_space_available_bytes
  , CASE WHEN $DELTA > 0 THEN 1 ELSE -1 END enough_space
  FROM
    DUAL
)
/
EOF

## Is there enough space available?
echo "--------------------"
if (( $DELTA > 0 )); then
    echo "Space is available"
    echo "--------------------"
    exit 0
else
    echo "Problem : Space NOT available"
    echo "--------------------"
    exit 1
fi

