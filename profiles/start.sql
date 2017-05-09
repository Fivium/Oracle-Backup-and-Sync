--
-- $Id: //Infrastructure/Database/scripts/profiles/start.sql#1 $
--

set linesize 180
set pagesize 999
select instance_name from v$instance;

select
  dbid
, name
, log_mode
from
  v$database;

column force_logging format a14
column scn format a14
column name format a14
column db_unique_name format a14
column flashback_on format a12
column flashbk_tbs format a11

select
  open_mode
, force_logging
, to_char(checkpoint_change#) scn
, database_role
, name
, db_unique_name
, flashback_on
, (select decode(to_char(count(1)),'0','YES','NO') flashbk_tbs from v$tablespace where FLASHBACK_ON !='YES') flashbk_tbs
from
  v$database;

select systimestamp from dual;

column start_scn format a16
column NAME format a40

SELECT * FROM(
  SELECT
    sequence#
  , TO_CHAR(first_change#) start_scn
  , applied
  , TO_CHAR(completion_time,'dd-mon-yyyy hh24:mi:ss') comp_time
  , SUBSTR(name, instr(name,'/',-1)+1) name
  FROM
       v$archived_log al
  WHERE
      sequence# > ( SELECT MAX(sequence#)-5 max_sequence# FROM v$archived_log al JOIN (SELECT resetlogs_change# FROM v$database) dbd ON dbd.resetlogs_change# = al.resetlogs_change# WHERE applied = 'YES' )
  AND resetlogs_change# = (SELECT resetlogs_change# FROM v$database)
  ORDER BY
    first_change# DESC
  , name
)
WHERE ROWNUM < 20;


