#!/bin/sh
#
# $Id: //Infrastructure/GitHub/Database/backup_and_sync/backup_scripts/db_backup.sh#1 $
#
# Backup the database
# - Work out the parameters and run the rman backup
#
NW='NOWHERE'
COMP='COMPRESS'
NOCOMP='NOCOMPRESS'
SYNC='SYNC'
NOSYNC='NOSYNC'

BACKUP_TYPE_DEFAULT='FULL_BACKUP'
RMAN_PROCESSES_DEFAULT='4'
DEL_DEFAULT='DELETE_OBSOLETE'
SYNC_ACTION_DEFAULT="$NOSYNC"
SYNC_TO_DEFAULT="$NW"
SYNC_TO_DIR_DEFAULT="$NW"
COMPRESS_DEFAULT='RMAN'
ZIP_THREADS_DEFAULT='ALL'
POST_RM_FILE_AGE_DAYS_DEFAULT='1'
FOR_STANDBY_DEFAULT='NOT_FOR_STANDBY'


function show_help {

cat << EOF

Usage:  db_backup.sh -s DBNAME -b BACKUPDIR [ -t -p -d -r -y -z -g -h -c -a -k -e ] 

-s : database sid you want to backup
-b : base backup directory
-t : backup type                     Options : FULL_BACKUP|ARCHIVELOGS_ONLY      Default : $BACKUP_TYPE_DEFAULT
-p : rman threads                    Options : any int                           Default : $RMAN_PROCESSES_DEFAULT
-d : rman deletion policy            Options : DEL_ALL_BK_FIRST|DELETE_OBSOLETE  Default : $DEL_DEFAULT
-r : rsync action                    Options : NOSYNC|WHOLE_BACKUP|POST_ZIP      Default : $SYNC_ACTION_DEFAULT
-y : rsync to server                 Options : any ip or hostname                Default : $SYNC_TO_DEFAULT
-z : remote directory                Options : any dir                           Default : $SYNC_TO_DIR_DEFAULT
-g : rsync to server 2               Options : any ip or hostname                Default : $SYNC_TO_DEFAULT
-h : remote directory server 2       Options : any dir                           Default : $SYNC_TO_DIR_DEFAULT
-c : compression                     Options : RMAN|ZIP|NOCOMPRESS               Default : $COMPRESS_DEFAULT
-a : zip threads                     Options : any int                           Default : $ZIP_THREADS_DEFAULT
-k : Days of zips to keep, not rman  Options : any int                           Default : $POST_RM_FILE_AGE_DAYS_DEFAULT
-e : backup standby control file     Options : FOR_STANDBY|NOT_FOR_STANDBY       Default : $FOR_STANDBY_DEFAULT

eg : db_backup.sh -s DB1 -b /oracle/backups -t ARCHIVELOGS_ONLY -r POST_ZIP -y db2.local -z /oracle/backups/from_db1 -c ZIP
--
-- This will : 
--   backup archivelogs for database DB1 to /oracle/backups directory
--   then use parallel gzip compression on the backup
--   then rsync this file to db2.local, remote directory /oracle/backups/from_db1
--

EOF

exit 0

}

## Option flags

while getopts :s:b:t:p:d:r:y:z:g:h:c:a:k:e: option; do

    case $option in
        s) ORASID="$OPTARG"                ;;
        b) BASE_DIR="$OPTARG"              ;;
        t) BACKUP_TYPE="$OPTARG"           ;;
        p) RMAN_PROCESSES="$OPTARG"        ;; 
        d) DEL="$OPTARG"                   ;;
        r) SYNC_ACTION="$OPTARG"           ;;
        y) SYNC_TO="$OPTARG"               ;;
        z) SYNC_TO_DIR="$OPTARG"           ;;
        g) SYNC_TO_2="$OPTARG"             ;;
        h) SYNC_TO_DIR_2="$OPTARG"         ;;
        c) COMPRESS="$OPTARG"              ;;
        a) ZIP_THREADS="$OPTARG"           ;;
        k) POST_RM_FILE_AGE_DAYS="$OPTARG" ;;
        e) FOR_STANDBY="$OPTARG"           ;;
        *) help="1"
           show_help                       ;;
    esac

done

#
# set defaults if nothing set
#
if [ -z "$BACKUP_TYPE"           ]; then BACKUP_TYPE="$BACKUP_TYPE_DEFAULT";                     fi
if [ -z "$RMAN_PROCESSES"        ]; then RMAN_PROCESSES=$RMAN_PROCESSES_DEFAULT;                 fi
if [ -z "$DEL"                   ]; then DEL="$DEL_DEFAULT";                                     fi
if [ -z "$SYNC_ACTION"           ]; then SYNC_ACTION="$SYNC_ACTION_DEFAULT";                     fi
if [ -z "$SYNC_TO"               ]; then SYNC_TO="$SYNC_TO_DEFAULT";                             fi
if [ -z "$SYNC_TO_DIR"           ]; then SYNC_TO_DIR="$SYNC_TO_DIR_DEFAULT";                     fi
if [ -z "$SYNC_TO_2"             ]; then SYNC_TO_2="$SYNC_TO_DEFAULT";                           fi
if [ -z "$SYNC_TO_DIR_2"         ]; then SYNC_TO_DIR_2="$SYNC_TO_DIR_DEFAULT";                   fi
if [ -z "$COMPRESS"              ]; then COMPRESS="$COMPRESS_DEFAULT";                           fi
if [ -z "$ZIP_THREADS"           ]; then ZIP_THREADS="$ZIP_THREADS_DEFAULT";                     fi
if [ -z "$POST_RM_FILE_AGE_DAYS" ]; then POST_RM_FILE_AGE_DAYS="$POST_RM_FILE_AGE_DAYS_DEFAULT"; fi
if [ -z "$FOR_STANDBY"           ]; then FOR_STANDBY="$FOR_STANDBY_DEFAULT";                     fi

#
# Work out what compression is needed
#
echo "compress $COMPRESS"

case $COMPRESS in
    RMAN)       RMAN_COMPRESS="$COMP"
                POST_COMPRESS="$NOCOMP" ;;
    ZIP)        RMAN_COMPRESS="$NOCOMP"
                POST_COMPRESS="$COMP"   ;;
    NOCOMPRESS) RMAN_COMPRESS="$NOCOMP"
                POST_COMPRESS="$NOCOMP" ;;
    *)          echo "Unkown option : $COMPRESS"
                show_help ;;
esac
#
# What type of rsync
#
echo "sync action $SYNC_ACTION"

case $SYNC_ACTION in
    NOSYNC)       BACKUP_SYNC="$NOSYNC"
                  SYNC_TO="$NW"
                  POST_COMPRESS_RSYNC="$NOSYNC" ;;
    WHOLE_BACKUP) BACKUP_SYNC="$SYNC" 
                  SYNC_TO="$SYNC_TO"                                  
                  POST_COMPRESS_RSYNC="$NOSYNC" ;;
    POST_ZIP)     BACKUP_SYNC="$NOSYNC"
                  SYNC_TO="$SYNC_TO" 
                  POST_COMPRESS_RSYNC="$SYNC"   ;;
esac

SERVER_NAME=`hostname`
LOGFILE_START="$BASE_DIR/logs/backup_${SERVER_NAME}_${ORASID}"
DATE_STR=`date +'%Y_%m_%d'`
LOGFILE="${LOGFILE_START}_${BACKUP_TYPE}_${DATE_STR}.log"
EMAIL_FILE="${LOGFILE_START}_EMAIL.txt"
BACKUP_ARGS="$ORASID $BACKUP_TYPE $RMAN_PROCESSES $BASE_DIR $DEL $FOR_STANDBY $BACKUP_SYNC $SYNC_TO $RMAN_COMPRESS $SYNC_TO_DIR"

echo ""
echo "ORASID                : $ORASID"
echo "BACKUP_TYPE           : $BACKUP_TYPE"
echo "RMAN_PROCESSES        : $RMAN_PROCESSES"
echo "BASE_DIR              : $BASE_DIR"
echo "DEL                   : $DEL"
echo "FOR_STANDBY           : $FOR_STANDBY"
echo "SYNC BACKUP           : $BACKUP_SYNC"
echo "SYNC_TO               : $SYNC_TO"
echo "SYNC_TO_DIR           : $SYNC_TO_DIR"
echo "SYNC_TO_2             : $SYNC_TO_2"
echo "SYNC_TO_DIR_2         : $SYNC_TO_DIR_2"
echo "RMAN COMPRESSION      : $RMAN_COMPRESS"
echo "POST_COMPRESS         : $POST_COMPRESS"
echo "POST_COMPRESS_THREADS : $ZIP_THREADS"
echo "POST_RM_FILE_AGE_DAYS : $POST_RM_FILE_AGE_DAYS"
echo "POST_COMPRESS_RSYNC   : $POST_COMPRESS_RSYNC"
echo ""
echo "Backup Args           : $BACKUP_ARGS"
echo ""
echo "Logging to            : $LOGFILE"
echo ""

#
# Run the rman script
#
$BASE_DIR/scripts/rman_backup.sh $BACKUP_ARGS > $LOGFILE 2>&1
#
# Was there a problem?
# - then exit
#

#
# Purge logs on full backup
#
if [ "$BACKUP_TYPE" = "FULL_BACKUP" ]; then
    $BASE_DIR/scripts/oracle_log_purge.sh $ORASID 2880 >> $LOGFILE 2>&1
fi

#
# Delete old logfile
#
echo "Delete old logfiles" >> $LOGFILE
find $BASE_DIR/logs/ -wholename "$LOGIFLE_START*" -mtime +1 -print -delete >> $LOGFILE 2>&1

#
# Post backup compress?
#
if [ "$POST_COMPRESS" = "$COMP" ]; then
    UPPER_SID=`echo $ORASID | tr  "[:lower:]" "[:upper:]"`
    BACKUP_DIR="${BASE_DIR}/files/${UPPER_SID}/${HOSTNAME}"
    BACKUP_FILES="${BACKUP_DIR}/*"
    ZIPS_DIR="${BASE_DIR}/files/zips"
    TARFILE_NAME_BASE="backup_${SERVER_NAME}_${ORASID}"
    DATE_STR=`date +'%Y_%m_%d_%H_%M_%S'`    
    TARFILE="${ZIPS_DIR}/${TARFILE_NAME_BASE}_${BACKUP_TYPE}_${DATE_STR}.tgz"
    
    echo "" 
    echo "Parallel zip of : $BACKUP_FILES"
    echo "             to : $TARFILE"
    echo ""
    #
    # Check pigs is install
    #
    PIGS_INSTALLED=`which pigz`
    if [ $? -eq 0 ]; then    
        #
        # Zip in parallel
        #
        tar -I pigz -cf $TARFILE $BACKUP_FILES --remove-files 
        #
        # Success?
        #
        if [ $? -eq 0 ]; then

            if [ -n "$ZIPS_DIR" ] && [ -d "$ZIPS_DIR" ]  && [ -n "$POST_RM_FILE_AGE_DAYS" ]; then
                #
                # Housekeeping
                #
                echo ""
                echo "Housekeep old zips"
                echo "Look in      : $ZIPS_DIR"
                echo "Files like   : $TARFILE_NAME_BASE"
                echo "Days to keep : $POST_RM_FILE_AGE_DAYS"
                echo ""
                find $ZIPS_DIR -name "${TARFILE_NAME}*.tgz" -type f -mtime "+${POST_RM_FILE_AGE_DAYS}" -print -delete
            fi

        else
            #
            # Delete old
            #
            echo ""
            echo "Tar zip failed!"
            exit 66

        fi
    else
        echo ""
        echo "No pigz installed!"
        exit 77
    fi
    #
    # Rsync the tar?
    #
    if [ "$POST_COMPRESS_RSYNC" = "$SYNC" ]; then
        #
        # Got somewhere to put it?
        #
        if [ -n "$SYNC_TO" ] && [ -n "$SYNC_TO_DIR" ] && [ "$SYNC_TO" != "$NW"  ] && [ "$SYNC_TO_DIR" != "$NW" ]; then
            echo ""
            echo "Sync : $TARFILE"
            echo "  to : $SYNC_TO:$SYNC_TO_DIR"
            echo ""
            rsync -av $TARFILE $SYNC_TO:$SYNC_TO_DIR
        else
            echo "" 
            echo "Nowhere to sync backup too! - No server or no dir given"
            echo ""
            exit 5
        fi
        #
        # Second sync location?
        #
        if [ -n "$SYNC_TO" ] && [ -n "$SYNC_TO_DIR" ] && [ "$SYNC_TO_2" != "$NW"  ] && [ "$SYNC_TO_DIR_2" != "$NW" ]; then
            echo ""
            echo "Sync : $TARFILE"
            echo "  to : $SYNC_TO_2:$SYNC_TO_DIR_2"
            echo ""            
            rsync -av $TARFILE $SYNC_TO_2:$SYNC_TO_DIR_2
        else
            echo "" 
            echo "No sync 2 or not configured correctly"
            echo ""
            exit 5
        fi        
    fi
fi
