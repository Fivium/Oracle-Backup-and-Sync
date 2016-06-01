--
-- $Id: //Infrastructure/Database/scripts/dbsync/database_code/process_logs_job.sql#1 $
--
SET SERVEROUTPUT ON
DECLARE
  X NUMBER;
BEGIN
  SYS.DBMS_JOB.SUBMIT
  ( job       => X
  , what      => 'dbamgr.dbsync.process_logs;'
  , next_date => SYSDATE
  , interval  => 'SYSDATE+10/1440 '
  , no_parse  => FALSE
  );
  SYS.DBMS_OUTPUT.PUT_LINE('Job Number is: ' || to_char(x));
  
  COMMIT;
END;
/

