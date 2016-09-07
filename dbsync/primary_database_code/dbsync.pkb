CREATE OR REPLACE PACKAGE BODY DBAMGR.dbsync
--
-- T Dale 2014-02-10
--
-- $Id: //Infrastructure/GitHub/Database/backup_and_sync/dbsync/primary_database_code/dbsync.pkb#2 $
AS
  SUBTYPE str_type IS VARCHAR2(30);
  
  c_error_str       CONSTANT str_type := 'ERROR!!!';
  
  TYPE log_details_type IS RECORD 
  (
    filename         VARCHAR2(1000)
  , directory_name   VARCHAR2(100)
  , log_clob         CLOB
  , log_line_count   INT
  , clob_load_error  BOOLEAN
  , last_applied_seq INT
  , apply_error      str_type
  );
  
  TYPE redo_log_deatils_rec_type IS RECORD
  (
    until_scn  v$archived_log.next_change#%TYPE := NULL
  , until_date v$archived_log.next_time%TYPE    := NULL  
  );

  PROCEDURE p(p_str VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE(p_str); END;

  PROCEDURE handle_error( p_msg VARCHAR2 )
  IS
  BEGIN
    p('ERROR : '||p_msg);
    --
    -- Only processing logs so just a message
    --
  END;
  
  FUNCTION file_exists( p_directory_name VARCHAR2, p_file_name VARCHAR2 ) 
    RETURN BOOLEAN
  IS
    l_file_exist BOOLEAN;
    l_size       NUMBER;
    l_block_size NUMBER;
  BEGIN
    UTL_FILE.FGETATTR( p_directory_name, p_file_name, l_file_exist,l_size, l_block_size );
    
    IF l_file_exist THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;

  END; 

  PROCEDURE read_line( 
    p_file_handle         UTL_FILE.FILE_TYPE
  , p_line_out        OUT VARCHAR2
  , p_end_of_file_out OUT BOOLEAN
  )
  IS
    l_line VARCHAR2(2000);
  BEGIN
    UTL_FILE.GET_LINE(p_file_handle, p_line_out);
    p_end_of_file_out := FALSE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_end_of_file_out := TRUE;
  END;
    
  PROCEDURE process_log_file( p_log_details IN OUT NOCOPY log_details_type )  
  --
  -- Get the clob from a OS file in the sync logs directory
  -- scrape log while we load it
  --
  IS
    c_roll_forward_str          CONSTANT VARCHAR2(100) := 'set until sequence'; 
    c_roll_forward_str_len      CONSTANT INT := LENGTH( c_roll_forward_str );
    
    l_handle       UTL_FILE.FILE_TYPE;
    l_line         VARCHAR2(1000);
    l_line_count   NUMBER := 0;
    l_clob         CLOB   := EMPTY_CLOB;
    l_seq_str_len  INT;
    l_seq_str      VARCHAR2(100);
    l_eof          BOOLEAN := FALSE;

    PROCEDURE clob_append(p_line VARCHAR2) IS
      l_line VARCHAR2(2000) := p_line || CHR(10);
    BEGIN
      DBMS_LOB.WRITEAPPEND( l_clob, LENGTH(l_line), l_line );
    END;
        
  BEGIN
    DBMS_LOB.CREATETEMPORARY(l_clob,TRUE);
    DBMS_LOB.OPEN( l_clob, DBMS_LOB.LOB_READWRITE );
    --
    -- Check file exists
    --
    IF NOT file_exists( p_log_details.directory_name, p_log_details.filename ) THEN
      handle_error( 'Logfile ' || p_log_details.filename || ' does not exist in directory ' || p_log_details.directory_name );
    ELSE
      --
      -- Extract to clob
      --
      l_handle := UTL_FILE.FOPEN( p_log_details.directory_name, p_log_details.filename, 'R');

      read_line( l_handle, l_line, l_eof );
      <<READ_FILE>>
      WHILE NOT l_eof 
      LOOP
        --
        -- Rollforward command?
        --
        IF l_line LIKE c_roll_forward_str||'%' THEN
          --
          -- Get the sequence
          -- - The command ends with a ';' 
          --
          l_seq_str_len := LENGTH( l_line ) - ( c_roll_forward_str_len + 1 );
          l_seq_str     := SUBSTR( l_line, c_roll_forward_str_len + 1, l_seq_str_len );
          p_log_details.last_applied_seq := TO_NUMBER( l_seq_str );
        END IF;
        --
        -- Check for any errors
        --
        IF l_line LIKE '%'||c_error_str||'%' THEN
          p_log_details.apply_error := c_error_str;
        END IF;
        
        clob_append(l_line);
        l_line_count := l_line_count + 1;
        --
        -- Read next line
        --
        read_line( l_handle, l_line, l_eof );

      END LOOP READ_FILE;
    
      p_log_details.log_clob        := l_clob;
      p_log_details.log_line_count  := l_line_count;
      p_log_details.clob_load_error := FALSE;
      --
      -- Tidy up
      --
      UTL_FILE.FCLOSE(l_handle);
      DBMS_LOB.CLOSE(l_clob);
      DBMS_LOB.FREETEMPORARY(l_clob);
      
    END IF;

  END;

  PROCEDURE refresh_standby_master_table(p_db_name v$database.name%TYPE)
  --
  -- Update the master table
  -- with basic details from the logs
  --
  IS
  BEGIN
    p( 'Check if there are any new standbys from this database : '|| p_db_name );
    --
    -- Check if we have any new standby db's
    --
    FOR l_rec IN (SELECT table_name FROM user_tables WHERE table_name LIKE 'DBSYNC_LOGS%') LOOP
      p('Checking for new standbys in '||l_rec.table_name);
      EXECUTE IMMEDIATE
      'MERGE INTO dbamgr.dbsync_standby registered_standby USING(
        SELECT 
          DISTINCT
          standby_server
        , standby_sid
        FROM 
          dbamgr.'|| l_rec.table_name ||' logs 
        WHERE
          UPPER(logs.db_name) = :p_db_name
      ) standby_logs
      ON(  
        registered_standby.standby_server = standby_logs.standby_server AND
        registered_standby.standby_sid    = standby_logs.standby_sid
      )
      WHEN NOT MATCHED THEN
        INSERT(
          standby_id
        , standby_server
        , standby_sid
        )
        VALUES(
          dbamgr.dbsync_standby_seq.NEXTVAL
        , standby_logs.standby_server
        , standby_logs.standby_sid
        )'
      USING p_db_name;
          
      p('Standby''s added : '||SQL%ROWCOUNT);
      p( '-' );      
    END LOOP;
    p('');
  
  END;
  
  FUNCTION redo_log_deatils( p_redo_log_sequence v$archived_log.sequence#%TYPE )
    RETURN redo_log_deatils_rec_type
  IS
    l_redo_log_deatils_rec redo_log_deatils_rec_type;
  BEGIN
    SELECT 
      standby_applied_until_scn
    , standby_applied_until_date
    INTO     
      l_redo_log_deatils_rec.until_scn
    , l_redo_log_deatils_rec.until_date  
    FROM
    (
        SELECT
          --
          -- Details of archived redo's
          --                   
          next_change# standby_applied_until_scn               
        , next_time    standby_applied_until_date
        FROM
          v$archived_log
        WHERE  
          sequence#         = p_redo_log_sequence AND
          dest_id           = 1                   AND
          resetlogs_change# = ( SELECT resetlogs_change# FROM v$database )
      UNION
        SELECT
          --
          -- If its the current redo then 
          -- we need to get the details of the 
          -- start of the changes 
          -- 
          first_change# standby_applied_until_scn               
        , first_time    standby_applied_until_date
        FROM
          v$log
        WHERE 
          sequence#  = p_redo_log_sequence AND
          status     = 'CURRENT'           AND
          first_time > SYSDATE - 1 
    );
    
    RETURN l_redo_log_deatils_rec;
                          
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p('-- Can''t find details on logfile sequence : ' || NVL( TO_CHAR( p_redo_log_sequence ), 'NULL') );
      RETURN l_redo_log_deatils_rec;        
  END;
  
  FUNCTION logfile_processed( p_logfile_name dbamgr.dbsync_standby_hist.logfile_name%TYPE )
  --
  -- Have we already processed this?
  -- 
    RETURN BOOLEAN
  IS
    
    CURSOR c_logfile IS ( SELECT 1 found FROM dbamgr.dbsync_standby_hist WHERE logfile_name = p_logfile_name );
    r_logfile c_logfile%ROWTYPE;
    
    l_logfile_found BOOLEAN := FALSE;      
  BEGIN
    OPEN c_logfile;
      FETCH c_logfile INTO r_logfile;
      IF c_logfile%FOUND THEN 
        l_logfile_found := TRUE;
      END IF;
    CLOSE c_logfile; 
    
    RETURN l_logfile_found;
  END;
  
  PROCEDURE process_logs
  --
  -- Check and process any logs
  -- from the standby server
  --
  IS
    l_db_name                 v$database.name%TYPE;
    l_standby_id              dbamgr.dbsync_standby.standby_id%TYPE;
    l_apply_start             DATE;
    l_apply_end               DATE;
    l_logs_checked            INT := 0;
    l_master_recs_updated     INT := 0;
    l_log_details             log_details_type;
    l_log_details_empty       log_details_type;
    l_primary_redolog_seq     v$log.sequence#%TYPE;
    l_standby_applied_details redo_log_deatils_rec_type;
    l_directory_path          all_directories.directory_path%TYPE;

    TYPE cur_typ IS REF CURSOR;
    
    l_log_dir_cur cur_typ; 
    l_logfile_cur cur_typ;
     
    l_table_and_dir_name VARCHAR2(100);
    logfile_rec          dbamgr.dbsync_logs_1%ROWTYPE;
    
    c_rollforward  CONSTANT VARCHAR2(20) := 'ROLLFORWARD';
    c_full_restore CONSTANT VARCHAR2(20) := 'FULL';
    c_date_fmt     CONSTANT VARCHAR2(30) := 'YYYY_MM_DD_HH24_MI_SS';
    c_days_to_keep CONSTANT INT          := 7;
  BEGIN
    --
    -- What db is this?
    --
    SELECT name INTO l_db_name FROM v$database;
    --
    -- Update master
    --
    refresh_standby_master_table(l_db_name);
    --
    -- Get current logfile sequence for the primary
    --
    SELECT 
      sequence# INTO l_primary_redolog_seq 
    FROM 
      v$log 
    WHERE
      status = 'CURRENT';
      
    p('Update master with this databases current logfile sequence : ' || l_primary_redolog_seq);
    
    UPDATE dbamgr.dbsync_standby SET primary_current_redolog_seq = l_primary_redolog_seq;
                
    p('Now check for new logfiles');
    OPEN l_log_dir_cur FOR 'SELECT table_name FROM user_tables WHERE table_name LIKE ''DBSYNC_LOGS%'' ';
    LOOP
      FETCH l_log_dir_cur INTO l_table_and_dir_name;
      EXIT WHEN l_log_dir_cur%NOTFOUND;
      
      SELECT directory_path INTO l_directory_path FROM all_directories WHERE directory_name = l_table_and_dir_name;
      p('-');
      p('- Checking in directory     : '|| l_table_and_dir_name || ' - Path : ' || l_directory_path );
      p('- Looking in external table : '|| l_table_and_dir_name ); 
      p('-');      
      --
      -- dbamgr.dbsync_logs is an external table
      -- populated by the dbsync job running on the standby server
      --
      OPEN l_logfile_cur FOR 'SELECT * FROM dbamgr.'||l_table_and_dir_name;
      LOOP
        FETCH l_logfile_cur INTO logfile_rec;
        EXIT WHEN l_logfile_cur%NOTFOUND;
        
        l_log_details                := l_log_details_empty;
        l_log_details.directory_name := l_table_and_dir_name;
      
        l_logs_checked := l_logs_checked + 1;
        --
        -- Is the log for this database?
        --
        IF UPPER(logfile_rec.db_name) = l_db_name THEN
          --
          -- Get the standby id
          --
          SELECT 
            standby_id INTO l_standby_id
          FROM 
            dbamgr.dbsync_standby 
          WHERE
            standby_server = logfile_rec.standby_server AND
            standby_sid    = logfile_rec.standby_sid; 
          --
          -- Already Processed?
          --
          IF logfile_processed( logfile_rec.logfile_name ) THEN
            p( '-- logfile already processed : ' || logfile_rec.logfile_name );           
          ELSE
            --
            -- Process logfile
            --
            l_log_details.filename := logfile_rec.logfile_name;        
            process_log_file( l_log_details );
            l_apply_start := TO_DATE( logfile_rec.start_date, c_date_fmt );
            l_apply_end   := TO_DATE( logfile_rec.end_date  , c_date_fmt );

            p( '-' );
            p( '-- New logfile                 : ' || logfile_rec.logfile_name       );
            p( '-- Standby id                  : ' || l_standby_id                   );
            p( '-- DBSYNC MODE                 : ' || logfile_rec.apply_mode         );
            p( '-- Apply error                 : ' || l_log_details.apply_error      );
            p( '-- Primary Current redolog seq : ' || l_primary_redolog_seq          );
            p( '-- Standby sync start          : ' || logfile_rec.start_date         );
            p( '-- Standby sync end            : ' || logfile_rec.end_date           ); 
         
            --
            -- Uppdate master is its a new standby details
            --
            IF logfile_rec.apply_mode = c_rollforward THEN
              --
              -- Update master with rollforward details, if newer
              --
              UPDATE dbamgr.dbsync_standby d 
                SET 
                  d.last_rollforward_start      = l_apply_start
                , d.last_rollforward_end        = l_apply_end 
                , d.last_rollforward_log        = l_log_details.log_clob
                , d.standby_applied_redolog_seq = l_log_details.last_applied_seq
                , d.last_rollforward_status     = l_log_details.apply_error
              WHERE
                standby_id = l_standby_id AND
                (
                  l_apply_start > d.last_rollforward_start 
                  OR
                  d.last_rollforward_start IS NULL
                );
          
            ELSIF logfile_rec.apply_mode = c_full_restore THEN
              --
              -- Update master with full refresh details, if newer
              --
              UPDATE dbamgr.dbsync_standby d 
                SET 
                  d.last_full_refresh_start     = l_apply_start
                , d.last_full_refresh_end       = l_apply_end
                , d.last_full_refresh_log       = l_log_details.log_clob
                , d.standby_applied_redolog_seq = l_log_details.last_applied_seq
                , d.last_full_refresh_status    = l_log_details.apply_error          
              WHERE
                standby_id = l_standby_id AND
                (
                  l_apply_start > d.last_full_refresh_start 
                  OR
                  d.last_full_refresh_start IS NULL
                );
            
            END IF;               


            --
            -- Was this new?
            --
            l_master_recs_updated := SQL%ROWCOUNT;
        
            IF l_master_recs_updated > 0 THEN
        
              p( '-- Master records updated      : ' || l_master_recs_updated );
              --
              -- Find out the standby lag
              --
              l_standby_applied_details := redo_log_deatils( l_log_details.last_applied_seq );
              --
              -- Update master with standbys lastest applied info
              --
              UPDATE 
                dbamgr.dbsync_standby
              SET
                standby_applied_until_scn  = l_standby_applied_details.until_scn
              , standby_applied_until_date = l_standby_applied_details.until_date 
              WHERE 
                standby_id = l_standby_id;


              p( '-- Standby applied until       : ' || TO_CHAR( l_standby_applied_details.until_date, 'DD-Mon-YYYY HH24:mi:ss') ); 
              p( '-- Standby Last applied seq    : ' || l_log_details.last_applied_seq );          
              --
              -- Save in history
              --
              INSERT INTO dbamgr.dbsync_standby_hist
              (
                hist_id
              , standby_id 
              , action
              , logfile_name
              , logfile
              , status
              , apply_start
              , apply_end
              , standby_applied_redolog_seq
              , standby_applied_until_scn  
              , standby_applied_until_date  
              , primary_current_redolog_seq 
              , primary_current_scn         
              , primary_current_date        
              )
              VALUES(
                dbamgr.dbsync_standby_hist_seq.NEXTVAL
              , l_standby_id
              , logfile_rec.apply_mode
              , logfile_rec.logfile_name
              , l_log_details.log_clob
              , l_log_details.apply_error
              , l_apply_start
              , l_apply_end
              , l_log_details.last_applied_seq
              , l_standby_applied_details.until_scn
              , l_standby_applied_details.until_date
              , l_primary_redolog_seq
              , dbms_flashback.get_system_change_number
              , SYSDATE
              );
              p( '-- New log added to history');  
              p( '-' );
            ELSE                      
              p( '--' );
              p( '-- Old log not saved' );                
              p( '--' );
            END IF;
              
          END IF;
          
        END IF;
      
      END LOOP;
      CLOSE l_logfile_cur;
    END LOOP;
    CLOSE l_log_dir_cur;  
    --
    -- House keep and commit
    --

    p( '-' );
    p( 'Logfiles checked     : ' || l_logs_checked );
    DELETE FROM 
      dbamgr.dbsync_standby_hist 
    WHERE 
      apply_end < SYSDATE - c_days_to_keep;
    p( 'History recs deleted : ' || SQL%ROWCOUNT );
    p( '-' );
    COMMIT;
  END;
END;
/