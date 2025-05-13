#!/bin/bash

function msg {
    echo "--"
    echo "-- $1"
    echo "--"
}

export ORACLE_SID=$1
STOP_START=$2

if [ $# -ne 2 ]
then
    echo "Expected 2 args got $#"
    echo ""
    echo "USAGE : stop_start_db.sh ORACLE_SID STOP|START|START_UPGRADE"
    echo ""
    exit 1
fi

case $STOP_START in

  START)
    SQL_CMD='STARTUP;';;

  STOP)
    SQL_CMD='SHUTDOWN IMMEDIATE;';;

  START_UPGRADE)
    SQL_CMD='STARTUP UPGRADE;';;

  *)
    echo "ERROR : unknown option "$STOP_START
    exit 1
    ;;
esac

msg "CMD : ${SQL_CMD}"

export ORACLE_HOME=`cat /etc/oratab|grep ^$ORACLE_SID:|cut -f2 -d':'`
PATH=$ORACLE_HOME/bin:$PATH
export PATH

/oracle/product/19se/db1/bin/sqlplus / as sysdba << EOF
WHENEVER OSERROR EXIT FAILURE ROLLBACK
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
$SQL_CMD
EOF

SQLPLUS_RETURN_CODE=$?

if [ $SQLPLUS_RETURN_CODE -ne 0 ]
then
    msg "ERROR - Return Code from SQLPLUS : $SQLPLUS_RETURN_CODE"
    exit $SQLPLUS_RETURN_CODE
fi

exit 0
