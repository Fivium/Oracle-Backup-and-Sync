#!/bin/sh
#
# $Id: //Infrastructure/GitHub/Database/backup_and_sync/dbsync/scripts/new_instance.sh#2 $
#
# T Dale 2014-02-11
# 
# Copy config and start new instace nomount
# ready to to become a new standby
#
function replace_placeholder {
    REPLACE_STR=$2
    ESCAPED_STR=${REPLACE_STR//'/'/'\/'}
    echo "Replacing placeholder '$1' with '$ESCAPED_STR'"
    sed -i s/"$1"/"$ESCAPED_STR"/g $3
}
echo ""
#
# Check cmd args
#
ARG_COUNT=7
if [ $# -ne $ARG_COUNT ]
then
    echo "Argument count wrong expected $ARG_COUNT, got $#"
    echo "ERROR - Syntax : $0 ORACLE_SID DATABASE_NAME SGA_SIZE PGA_SIZE FRA_SIZE TEMPLATE_PATH DB_BACKUP_PATH"
    exit 1
fi

export ORACLE_SID=$1
UPPER_SID=`echo $ORACLE_SID | tr  "[:lower:]" "[:upper:]"`
DB_NAME=$2
SGA_SIZE=$3
PGA_SIZE=$4
FRA_SIZE=$5
TEMPLATE_PATH=$6
DB_BACKUP_PATH=$7
PLACEHOLDER_SID='__ORACLE_SID__'
HOSTNAME=`hostname`

SMON="smon_$ORACLE_SID"
TEST=`ps -ef |grep $SMON|grep -v grep|wc -l`

if [ "$TEST" != 0 ]; then
    echo "Instance already running, process $SMON is running!"
    exit 1;
fi
#
# Need an oratab entery
#
ORATAB='/etc/oratab'
export ORACLE_HOME=`cat $ORATAB|grep ^$ORACLE_SID:|cut -f2 -d':'`
if [ -z "$ORACLE_HOME" ]; then
    echo "No entry for Oracle Sid : '$ORACLE_SID' in Oratab '$ORATAB', please enter"
    exit 2;
fi

PATH=$ORACLE_HOME/bin:$PATH
export PATH
#
# Check for init.ora
#
INIT_ORA="$ORACLE_HOME/dbs/init${ORACLE_SID}.ora"
if [ -f "$INIT_ORA" ]; then
    echo "File $INIT_ORA already exists, please delete if this is the correct sid"
    exit 3;
fi
#
# dbsync config
#
CONFIG_TEMPLATE="$TEMPLATE_PATH/HOSTNAME_SID.sh"
if [ ! -f "$CONFIG_TEMPLATE" ]; then
    echo "File $CONFIG_TEMPLATE doesn't exist, strange!"
    exit 4;
fi
#
# New config file
#
CONFIG_FILE="$TEMPLATE_PATH/${HOSTNAME}_${ORACLE_SID}.sh"
if [ -f "$CONFIG_FILE" ]; then
    echo "Config file $CONFIG_FILE alread exists, please delete if you want to run this auto add"
    exit 4;
fi

echo "Create config file $CONFIG_FILE from template $CONFIG_TEMPLATE"
cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
#
# Replacements for config file
#
replace_placeholder '__DB_BACKUP_PATH__' $DB_BACKUP_PATH $CONFIG_FILE
replace_placeholder '__DB_NAME__'  $DB_NAME $CONFIG_FILE
replace_placeholder '__STANDBY_SID__'  $ORACLE_SID $CONFIG_FILE
replace_placeholder '__HOSTNAME__'  $HOSTNAME $CONFIG_FILE
#
# Copy over init.ora template
#
INIT_ORA_TEMPLATE="$TEMPLATE_PATH/init${PLACEHOLDER_SID}.ora"
if [ ! -f "$INIT_ORA_TEMPLATE" ]; then
    echo "File $INIT_ORA_TEMPLATE doesn't exist, strange!"
    exit 4;
fi

echo ""
echo "Create pfile $INIT_ORA from template $INIT_ORA_TEMPLATE"
cp "$INIT_ORA_TEMPLATE" "$INIT_ORA"

echo ""
replace_placeholder $PLACEHOLDER_SID $ORACLE_SID $INIT_ORA
replace_placeholder '__DB_NAME__'  $DB_NAME $INIT_ORA
replace_placeholder '__UPPER_SID__' $UPPER_SID $INIT_ORA
replace_placeholder '__SGA_SIZE__' $SGA_SIZE $INIT_ORA
replace_placeholder '__PGA_SIZE__' $PGA_SIZE $INIT_ORA
replace_placeholder '__FRA_SIZE__' $FRA_SIZE $INIT_ORA
echo ""

echo "Start the instance nomount"
$ORACLE_HOME/bin/sqlplus / as sysdba << EOF
startup nomount;
exit;
EOF
