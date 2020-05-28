--
-- $Id$
--
set pagesize 0
set heading off
set trimspool on
set trimout on
set linesize 200
set feedback off
set verify off
def full_or_rollforward=&1
def open_noopen=&2
def file_path=&3
spool &4

SET SERVEROUTPUT ON
DECLARE
  l_database_last_log_applied INT;
  l_log_sequence_we_can_apply INT;
  l_max_cataloged_sequence    INT;
  l_log_sequence_we_can_apply_n INT;
  v_msg    VARCHAR(100);
  v_msg2    VARCHAR(100);




  PROCEDURE p(p_str VARCHAR2)  IS BEGIN DBMS_OUTPUT.PUT_LINE(p_str); END;
BEGIN
  --
  -- Current applied log
  --

     select sequence# INTO l_database_last_log_applied from (
        select min (a.sequence#) sequence#, min (b.checkpoint_change#) from v$archived_log a, v$datafile b
        where b.checkpoint_change# between first_change# and next_change# and rownum <=1 group by a.sequence#
        );



   --
  -- What can we apply too
  --
  SELECT
    MAX(none_missing.sequence#) max_sequence_with_none_missing INTO l_log_sequence_we_can_apply
  FROM
    (
      SELECT
        sequence#
      FROM
        (
          SELECT sequence# FROM v$backup_archivelog_details
          UNION
          SELECT sequence# FROM v$archived_log WHERE status = 'A'
        )
      CONNECT BY sequence# = PRIOR sequence#+1
      START WITH sequence# = l_database_last_log_applied
    ) none_missing;
  --
  -- What is the max in the catalog
  --
  SELECT
    MAX(sequence#) INTO l_max_cataloged_sequence
  FROM
    (
      SELECT sequence# FROM v$backup_archivelog_details
      UNION
      SELECT sequence# FROM v$archived_log
    );


  p('# Last applied log sequence : '||l_database_last_log_applied);
  p('# We can apply to           : '||l_log_sequence_we_can_apply);
  p('# Last in the catalog       : '||l_max_cataloged_sequence);
  p('#==================================================#');

  CASE
    WHEN  l_max_cataloged_sequence > l_log_sequence_we_can_apply THEN
                v_msg := l_log_sequence_we_can_apply;
                v_msg2 := '#Gaps in archivelog detected. Maximum sequence without gaps to be applied';

           p(v_msg2);
           p('run{' );
           p('set until sequence' || ' ' || v_msg || ';');





        WHEN l_log_sequence_we_can_apply = l_log_sequence_we_can_apply THEN
                v_msg := l_max_cataloged_sequence;
                v_msg2 := '#No lag detected latest archivelog recovery to be applied';

           p(v_msg2);
           p('run{' );
           p('set until sequence' || ' ' || v_msg+1 || ';');





        WHEN  l_log_sequence_we_can_apply is NULL THEN
                l_log_sequence_we_can_apply_n := COALESCE (l_log_sequence_we_can_apply,l_database_last_log_applied);
                v_msg := l_log_sequence_we_can_apply_n;
                v_msg2 := '#Cannot find valid archivelog to proceed';

          p(v_msg2);
          p('run{' );
          p('set until sequence' || ' ' || v_msg || ';');


  END CASE;


END;

/


SELECT
     --
     -- Create new file names and path
     -- this will macke sure the files are created where you want them
     --
     'set newname for datafile '     ||
     f.file#                         ||
     ' to "&file_path'               || '/' ||
     t.name                          || '_' ||
     ltrim( to_char( rank() over (partition by t.name order by f.file#), '00') ) ||
     '.dbf";' ts_file
FROM
     v$datafile   f
JOIN v$tablespace t ON t.ts# = f.ts#
WHERE
     --
     -- Only move datafile on full rebuild
     --
     'FULL'='&full_or_rollforward'
ORDER BY
     t.name
/
SELECT
  --
  -- Need the database to be mounted
  --
  CASE WHEN open_mode IN ('READ WRITE','READ ONLY') THEN
    --
    -- Shut it down and start how we want
	    'shutdown immediate;'||CHR(10)||'startup mount;'
  END open_mount_cmds
FROM
  v$database
/
SELECT
  --
  -- Full database restore?
  --
  CASE WHEN '&full_or_rollforward'='FULL' THEN
    'restore database;'              || CHR(10) ||
    'switch datafile all;'
  END                                || CHR(10) ||
  --
  -- Always a recover
  --
  'recover database;'                || CHR(10) ||
  --
  -- Open database or leave in recovery mode (mounted)
  --
  CASE
    WHEN '&open_noopen'='OPEN' THEN
      'alter database open resetlogs;'
    WHEN '&open_noopen'='OPEN_READ_ONLY' THEN
      'sql ''alter database open read only'';'
  END                                || CHR(10) ||
  '}'
FROM
  dual
/
spool off

                                                      
