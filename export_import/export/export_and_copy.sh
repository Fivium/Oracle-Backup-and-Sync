#!/bin/bash
export ORACLE_HOME=/oracle/product/19se/db1
export ORACLE_SID=<SID>
export PATH=$PATH:/oracle/product/19se/db1/bin

expdp parfile=/oracle_backups/files/ECDLV1/data_pump/full_export.par

EXPORT_LOGFILE='/oracle_backups/files/ECDLV1/data_pump/expdp_full.log'
HAS_ERRORS=`grep 'error(s)' $EXPORT_LOGFILE | wc -l`

if [[ $HAS_ERRORS -gt 0 ]]
then
    echo "#"
    echo "# Export has errors, don't copy"
    echo "#"
    grep -A1 error $EXPORT_LOGFILE
else
    scp -i ~/.ssh/<CERT> expdp_full.dmp.01 <REMOTE_SERVER>:/oracle_backups/files/<SID>/data_pump/
fi
