#!/bin/bash
export ORACLE_SID=$1
export ORACLE_HOME=`cat /etc/oratab|grep ^$ORACLE_SID:|cut -f2 -d':'`
export PATH=$ORACLE_HOME/bin:$PATH
BACKUP_DIR=$2
DATABASE_SIZE_BYTES=$(sqlplus -S / as sysdba << EOF
  set head off
  set feedback off
  set pagesize 5000
  set linesize 30000
  select TO_CHAR(SUM(bytes)) FROM v\$datafile;
  exit
EOF
)
DATABASE_SIZE_BYTES=`echo $DATABASE_SIZE_BYTES | tr "\n" " "`
SPACE_REQUIRED=$DATABASE_SIZE_BYTES
BUFFER_SIZE=50000000000
DEST_DIR=$BACKUP_DIR
## Get available space in DEST_DIR
SPACE_AVAILABLE=$(df $DEST_DIR -B1 -P | awk '{print $2}' | sed -e /1-blocks/d)
## Add buffer size
SPACE_REQUIRED_PLUS_BUFFER=$(($SPACE_REQUIRED+$BUFFER_SIZE))
DELTA=$(($SPACE_AVAILABLE-$SPACE_REQUIRED_PLUS_BUFFER))
## Debug
echo "--------------------"
echo "Database : "$ORACLE_SID
echo "--------------------"
echo "database_size_bytes : $DATABASE_SIZE_BYTES"
echo "SPACE_REQUIRED: $SPACE_REQUIRED"
echo "SPACE_REQUIRED_PLUS_BUFFER: $SPACE_REQUIRED_PLUS_BUFFER"
echo "SPACE_AVAILABLE: $SPACE_AVAILABLE"
echo "DELTA: $DELTA"
## Is there enough space available?
if (( $DELTA > 0 )); then
    echo "Space is available"
    exit 0
else
    echo "Space not available"
    exit 1
fi
echo ""
