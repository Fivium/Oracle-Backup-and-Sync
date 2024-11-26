#!/bin/bash
#
# $Id: //Infrastructure/GitHub/Database/backup_and_sync/backup_scripts/db_backup.sh#2 $
#
# Backup the database
# - Work out the parameters and run the rman backup
#

#
# Exit if backup already running
#
function set_current_secs {
     local __return_val=$1
     local __current_secs=$(date +%s)
     eval $__return_val="'$__current_secs'"
}

set_current_secs START_SECS

RUNNING=`ps -ef | grep "$0" | grep -v grep | wc -l`

if [ $RUNNING -gt 2 ]
then
    echo "`ps -ef | grep $0 | grep -v grep`"
    echo "Running count : $RUNNING, Script $0 is running, time to exit!"
    exit 1
fi

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
SKIP_DEFAULT='FALSE'

function show_help {

cat << EOF

Usage:  db_backup.sh -s DBNAME -b BACKUPDIR [ -t -p -d -r -y -z -g -h -c -a -k -e -m ] 

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
-m : skips backup for the instance   Options : TRUE|FALSE                        Default : $SKIP_DEFAULT

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

echo "default skip option:   $SKIP_DEFAULT"

## Option flags

while getopts :s:b:t:p:d:r:y:z:g:h:c:a:k:e:m: option; do

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
        m) SKIP="$OPTARG"                  ;;
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
if [ -z "$SKIP"                  ]; then SKIP="$SKIP_DEFAULT";                                   fi

#
# Work out what compression is needed
#

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
LOGFILE_DIR="$BASE_DIR/logs"
#
# Check directory exist
#
if [ ! -d "$BASE_DIR" ]; then
    echo "BASE DIR does not exist : $BASE_DIR"
    exit 12
fi
if [ ! -d "$LOGFILE_DIR" ]; then
    echo "LOGFILE DIR does not exist : LOGFILE_DIR"
    exit 13
fi

LOGFILE_START="$LOGFILE_DIR/backup_${SERVER_NAME}_${ORASID}"
DATE_STR=`date +'%Y_%m_%d'`
LOGFILE="${LOGFILE_START}_${BACKUP_TYPE}_${DATE_STR}.log"
EMAIL_FILE="${LOGFILE_START}_EMAIL.txt"
BACKUP_ARGS="$ORASID $BACKUP_TYPE $RMAN_PROCESSES $BASE_DIR $DEL $FOR_STANDBY $RMAN_COMPRESS $SKIP"

HOSTNAME=`hostname`
UPPER_SID=`echo $ORASID | tr  "[:lower:]" "[:upper:]"`
BACKUP_DIR="${BASE_DIR}/files/${UPPER_SID}/${HOSTNAME}"

#
# Display to stfout and log
#
function log {
    echo "$1" | tee -a $LOGFILE 
}
function log2 {
    log ""
    log "$1"
    log ""
}
function log3 {
    LINE='-------------------------------------------------------------------'
    log ""
    log "$LINE"
    log2 "$1"
    log "$LINE"
    log ""
}
function show_elapsed_time {
    set_current_secs CURRENT_SECS
    ELSPSED_SECS=$(( $CURRENT_SECS - $START_SECS ))
    log2 "Total Elapsed Seconds : $ELSPSED_SECS"
}
function show_section_elapsed_time {
    set_current_secs CURRENT_SECS
    SECTION_START_SEC="$1"
    SECTION_NAME="$2"

    ELSPSED_SECS=$(( $CURRENT_SECS - $SECTION_START_SEC ))
    log2 "Elapsed : $ELSPSED_SECS secs for $SECTION_NAME"
}
DATE=`date`
log3 "Start : $DATE"

log ""
log "ORASID                : $ORASID"
log "BACKUP_TYPE           : $BACKUP_TYPE"
log "RMAN_PROCESSES        : $RMAN_PROCESSES"
log "BASE_DIR              : $BASE_DIR"
log "BACKUP_DIR            : $BACKUP_DIR"
log "DEL                   : $DEL"
log "FOR_STANDBY           : $FOR_STANDBY"
log "SYNC_ACTION           : $SYNC_ACTION"
log "SYNC BACKUP           : $BACKUP_SYNC"
log "SYNC_TO               : $SYNC_TO"
log "SYNC_TO_DIR           : $SYNC_TO_DIR"
log "SYNC_TO_2             : $SYNC_TO_2"
log "SYNC_TO_DIR_2         : $SYNC_TO_DIR_2"
log "RMAN COMPRESSION      : $RMAN_COMPRESS"
log "POST_COMPRESS         : $POST_COMPRESS"
log "POST_COMPRESS_THREADS : $ZIP_THREADS"
log "POST_RM_FILE_AGE_DAYS : $POST_RM_FILE_AGE_DAYS"
log "POST_COMPRESS_RSYNC   : $POST_COMPRESS_RSYNC"
log "SKIPPING_BACKUP       : $SKIP"
log ""
log "Backup Args           : $BACKUP_ARGS"
log ""
log "Logging to            : $LOGFILE"
log ""

if [ "$BACKUP_TYPE" != "CROSSCHECK" ]; then
    #
    # Check there is enough space for the backup
    #
    $BASE_DIR/scripts/enough_space.sh $ORASID "${BASE_DIR}/files"
    RETURN_VAL=$?
    if [ $RETURN_VAL -ne 0 ]; then
        echo "Not enough space"
        log "!!!NOT ENOUGH SPACE TO BACKUP TO!!!"
        exit 1
    fi
fi

if [ "$BACKUP_TYPE" = "ENOUGH_SPACE_CHECK" ]; then
    log3 "Only run space check"
    exit 0
fi
#
# Run the rman script
#
set_current_secs BEFORE_RMAN_SECS
$BASE_DIR/scripts/rman_backup.sh $BACKUP_ARGS >> $LOGFILE 2>&1
show_section_elapsed_time $BEFORE_RMAN_SECS "RMAN Backup"
#
# Was there a problem?
# - then exit
#
if [ $? -ne 0 ]; then
    echo "Problem Running rman backup script"
    exit 1
fi
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
# Are we rsyncing the rman backup?
#
if [ "$BACKUP_SYNC" = "$SYNC" ]; then
    log ""
    log "Full backup dir rsync"
    log ""
    log "SYNC destination 1"

    if [ -d "$BACKUP_DIR" ] && [ -n "$SYNC_TO" ] && [ -n "$SYNC_TO_DIR" ] && [ "$SYNC_TO_DIR" != "NOWHERE" ] && [ "$SYNC_TO" != "NOWHERE" ]
    then
        set_current_secs BEFORE_SYNC_SECS
        log "Sync $BACKUP_DIR to $SYNC_TO:$SYNC_TO_DIR"
        rsync -av $BACKUP_DIR/* $SYNC_TO:$SYNC_TO_DIR >> $LOGFILE 2>&1
        show_section_elapsed_time $BEFORE_SYNC_SECS "RSYNC to $SYNC_TO:$SYNC_TO_DIR"
    else
        log3 "Sync Arg Error - from dir : $BACKUP_DIR - Sync to : $SYNC_TO - Sync to dir : $SYNC_TO_DIR"
        exit 5
    fi

    log ""
    log "SYNC destination 2"

    if [ -d "$BACKUP_DIR" ] && [ -n "$SYNC_TO_2" ] && [ -n "$SYNC_TO_DIR_2" ] && [ "$SYNC_TO_DIR_2" != "NOWHERE" ] && [ "$SYNC_TO_2" != "NOWHERE" ]
    then
        set_current_secs BEFORE_SYNC_SECS
        log "Sync $BACKUP_DIR to $SYNC_TO_2:$SYNC_TO_DIR_2"
        rsync -av $BACKUP_DIR/* $SYNC_TO_2:$SYNC_TO_DIR_2 >> $LOGFILE 2>&1
        show_section_elapsed_time $BEFORE_SYNC_SECS "RSYNC to $SYNC_TO_2:$SYNC_TO_DIR_2"
    else
        log "No second sync needed - second sync to : $SYNC_TO_2 - second sync to dir : $SYNC_TO_DIR_2"
    fi

fi
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
    
   
    
    log "" 
    log "Parallel zip of : $BACKUP_FILES"
    log "             to : $TARFILE"
    log ""
    #
    #
    #
    if [ ! -d "$ZIPS_DIR" ]; then
         log3 "No directory to put the tar zip, looking for : $ZIPS_DIR"
         exit 65
    fi
    #
    # Check pigs is install
    #
    PIGS_INSTALLED=`which pigz`
    if [ $? -eq 0 ]; then    
        #
        # Zip in parallel
        #
        log2 "pigz installed : $PIGS_INSTALLED, running tar with pigz compression"
        set_current_secs BEFORE_PIGZ_SECS
        tar -I pigz -cf $TARFILE $BACKUP_FILES --remove-files >> $LOGFILE 2>&1
        show_section_elapsed_time $BEFORE_PIGZ_SECS "PIGZ compress of $BACKUP_FILES to $TARFILE"
        ls -ltrh $TARFILE
        #
        # Success?
        #
        if [ $? -eq 0 ]; then

            if [ -n "$ZIPS_DIR" ] && [ -d "$ZIPS_DIR" ]  && [ -n "$POST_RM_FILE_AGE_DAYS" ]; then
                #
                # Housekeeping
                #
                log ""
                log "Housekeep old zips"
                log "Look in      : $ZIPS_DIR"
                log "Files like   : $TARFILE_NAME_BASE"
                log "Days to keep : $POST_RM_FILE_AGE_DAYS"
                log ""
                find $ZIPS_DIR -name "${TARFILE_NAME}*.tgz" -type f -mtime "+${POST_RM_FILE_AGE_DAYS}" -print -delete >> $LOGFILE 2>&1
            fi

        else
            #
            # Delete old
            #
            log3 "Tar zip failed!"
            exit 66

        fi
    else
        log3 "No pigz installed!"
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
            log ""
            log "Sync : $TARFILE"
            log "  to : $SYNC_TO:$SYNC_TO_DIR"
            log ""
            set_current_secs BEFORE_SYNC_SECS
            rsync -av $TARFILE $SYNC_TO:$SYNC_TO_DIR >> $LOGFILE 2>&1
            show_section_elapsed_time $BEFORE_SYNC_SECS "RSYNC"
        else
            log3 "Nowhere to sync backup too! - No server or no dir given"
            exit 5
        fi
        #
        # Second sync location?
        #
        if [ -n "$SYNC_TO" ] && [ -n "$SYNC_TO_DIR" ] && [ "$SYNC_TO_2" != "$NW"  ] && [ "$SYNC_TO_DIR_2" != "$NW" ]; then
            log ""
            log "Sync : $TARFILE"
            log "  to : $SYNC_TO_2:$SYNC_TO_DIR_2"
            log ""            
            set_current_secs BEFORE_SYNC_SECS
            rsync -av $TARFILE $SYNC_TO_2:$SYNC_TO_DIR_2 >> $LOGFILE 2>&1
            show_section_elapsed_time $BEFORE_SYNC_SECS "RSYNC"
        else
            log2 "No sync 2 or not configured correctly"
        fi        
    fi
fi

show_elapsed_time
DATE=`date`
log3 "End : $DATE"
