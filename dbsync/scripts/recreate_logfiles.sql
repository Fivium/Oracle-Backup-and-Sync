--
-- $Id: //Infrastructure/Database/scripts/dbsync/scripts/recreate_logfiles.sql#1 $
--
-- T Dale 2014-02-04
-- Recreate the redo
--   just a tidy up to omf
--   and a check db_create_online_log_dest_1 etc is set
--   - online_dest should be set
--
SET SERVEROUTPUT ON
DECLARE
  l_max_logfile_size  INT;
  l_max_logfile_group INT;
  l_cmd               VARCHAR2(1000);

  PROCEDURE p( p_str VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE(p_str); END;
BEGIN
  p( 'Getting current logfile details from v$log' );
  --
  -- Get current details
  --
  SELECT MAX(group#) INTO l_max_logfile_group FROM v$log;
  SELECT MAX(bytes ) INTO l_max_logfile_size  FROM v$log;

  p( 'Creating new logfiles' );
  FOR i IN 1..3 LOOP
    l_cmd := 'ALTER DATABASE ADD LOGFILE GROUP '||TO_CHAR(l_max_logfile_group+i)||' SIZE '||TO_CHAR(l_max_logfile_size);
    p( 'EXEC : ' || l_cmd );
    EXECUTE IMMEDIATE l_cmd;
  END LOOP;

  p( 'Drop old logfile' );
  FOR l_rec IN ( SELECT group# FROM v$log WHERE group# <= l_max_logfile_group ORDER BY group# ) LOOP
    l_cmd := 'ALTER DATABASE DROP LOGFILE GROUP '||TO_CHAR(l_rec.group#);
    p( 'EXEC : ' || l_cmd );
    EXECUTE IMMEDIATE l_cmd;
  END LOOP;  
END;
/
