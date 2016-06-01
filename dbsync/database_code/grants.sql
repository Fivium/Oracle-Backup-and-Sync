--
-- $Id$
--
grant select on v_$archived_log to dbamgr
/
grant select on v_$log to dbamgr
/
grant execute on dbms_flashback to dbamgr
/
grant read,write on directory dbsync_logs to dbamgr
/
