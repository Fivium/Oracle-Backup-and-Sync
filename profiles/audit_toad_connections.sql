begin
  dbms_audit_mgmt.clean_audit_trail(
   audit_trail_type        => dbms_audit_mgmt.audit_trail_unified,
   use_last_arch_timestamp => true);
end;
/
noaudit policy toad_connection
/
drop AUDIT POLICY toad_connection
/
CREATE AUDIT POLICY toad_connection
ACTIONS logon
WHEN 'UPPER(SYS_CONTEXT(''USERENV'', ''CLIENT_PROGRAM_NAME'')) = ''TOAD.EXE'' '
EVALUATE PER statement

--container = current
/
audit policy toad_connection
/
select *
from   audit_unified_policies
where  policy_name = 'TOAD_CONNECTION'
/
