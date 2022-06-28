SET LINESIZE 200
COL INSTANCE_LOCATION FORMAT A45

WITH applied_achivelog
AS(
    SELECT
      next_time       standby_recoved_until_time,
      completion_time apply_to_standby_time,
      recid
    FROM
      v$archived_log
    WHERE
      name          IS NOT NULL        AND
      registrar     IN ('RMAN','SRMN') AND
      first_change# < (SELECT current_scn FROM v$database) AND
      name          LIKE '%arc'
  UNION ALL
    SELECT
      CASE WHEN d.open_mode = 'READ WRITE' THEN SYSDATE ELSE SYSDATE - 100 END standby_recoved_until_time,
      CASE WHEN d.open_mode = 'READ WRITE' THEN SYSDATE ELSE SYSDATE - 100 END apply_to_standby_time,
      CASE WHEN d.open_mode = 'READ WRITE' THEN 9999999 ELSE -100          END recid
    FROM
      v$database d
)
, lastest_applied_achivelog
AS(
  SELECT
    *
  FROM
    applied_achivelog
  ORDER BY
    standby_recoved_until_time DESC
  FETCH FIRST 1 ROWS ONLY
)
SELECT
  ROUND((SYSDATE - laa.standby_recoved_until_time)*24*60)       lag_minutes,
  ROUND((SYSDATE - laa.apply_to_standby_time)*24*60)            last_apply_age_minutes,
  TO_CHAR(standby_recoved_until_time, 'DD-MON-YYYY HH24:MI:SS') standby_recoved_until_time,
  TO_CHAR(apply_to_standby_time     , 'DD-MON-YYYY HH24:MI:SS') last_rollforward_finish_time,
  ( SELECT instance_name||'@'||host_name FROM v$instance )      instance_location
FROM
    lastest_applied_achivelog laa
/
