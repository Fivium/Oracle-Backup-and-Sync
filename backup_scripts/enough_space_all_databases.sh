#!/bin/bash

BACKUP_DIR=${1:-}
FREE_PERCENT=${2:-}

usage() {
    echo "Usage: $0 <BACKUP_DIR> <FREE_PERCENT>"
    exit 1
}

if [ "$#" -ne 2 ]; then
    echo "Error: Exactly 2 arguments required."
    usage
fi

while IFS=':' read -r ORACLE_SID _; do
    if [[ -n "$ORACLE_SID" && "$ORACLE_SID" != \#* ]]; then
        echo "--"
        echo "-- Processing: $ORACLE_SID"
        echo "--"
        /oracle/backups/scripts/enough_space.sh $ORACLE_SID $BACKUP_DIR $FREE_PERCENT
    fi
done < /etc/oratab

echo "--"
echo "-- Done"
echo "--"
