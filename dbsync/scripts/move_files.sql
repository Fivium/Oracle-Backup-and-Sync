--
-- $Id: //Infrastructure/Database/scripts/dbsync/scripts/move_files.sql#1 $
--
set verify off
def test_exec=&1
def new_redo_path_1=&2
def new_redo_path_2=&3
def new_tempfile_path=&4
set linesize 200

SET SERVEROUTPUT ON
DECLARE
  c_new_redo_path_1   CONSTANT VARCHAR2(100) := '&new_redo_path_1';
  c_new_redo_path_2   CONSTANT VARCHAR2(100) := '&new_redo_path_2';
  c_test_exec         CONSTANT VARCHAR2(4)   := '&test_exec';
  c_new_tempfile_path CONSTANT VARCHAR2(100) := '&new_tempfile_path';
  l_count                      NUMBER;
  l_redo_path                  VARCHAR2(100);

  PROCEDURE p ( p_str VARCHAR2)                 IS BEGIN DBMS_OUTPUT.PUT_LINE(p_str);    END;
  FUNCTION  qw( p_str VARCHAR2) RETURN VARCHAR2 IS BEGIN RETURN CHR(39)||p_str||CHR(39); END;

  PROCEDURE run( p_sql VARCHAR2)
  IS
  BEGIN
    p( '---- RUN : ' || p_sql );
    IF c_test_exec = 'EXEC' THEN
      EXECUTE IMMEDIATE p_sql;
      p( '---- DONE' );
    END IF;
  END;

  PROCEDURE rename_file( p_old VARCHAR2, p_new VARCHAR2 )
  IS
  BEGIN
    run('ALTER DATABASE RENAME FILE '||qw(p_old)||' TO '||qw(p_new));
  END;
  
BEGIN
  p( 'Moving logfiles to new locations : ' || c_new_redo_path_1 || ' and ' || c_new_redo_path_2 );
  FOR logfile_group_rec IN ( SELECT group#, members  FROM v$log ORDER BY group# ) LOOP

    p( '--');
    p( '-- Moving group : ' || logfile_group_rec.group# || ' Number of members : ' || logfile_group_rec.members );
    l_count := 1;
 
   FOR logfile_rec IN ( SELECT member FROM v$logfile WHERE group# = logfile_group_rec.group# ) LOOP
      p('---- Moving member : ' || l_count || ' Old filename : ' ||logfile_rec.member);
      IF l_count = 1 THEN
        l_redo_path := c_new_redo_path_1;
      ELSE
        l_redo_path := c_new_redo_path_2;
      END IF;
      rename_file( logfile_rec.member, l_redo_path||'/redo_group_'||logfile_group_rec.group#||'_member_'||l_count||'.log' );
      l_count := l_count + 1;
    END LOOP;

  END LOOP;
 
  p( ' ' );
  p( 'Moving tempfiles to new location : ' || c_new_tempfile_path );

  l_count := 1;
  FOR tempfile_rec IN ( 
    SELECT 
      tf.name old_filename
    , ts.name tablespace_name
    FROM 
         v$tempfile   tf
    JOIN v$tablespace ts on tf.ts# = ts.ts#
    ) LOOP 
     rename_file( tempfile_rec.old_filename, c_new_tempfile_path||'/'||tempfile_rec.tablespace_name||'_'||TO_CHAR( l_count )||'.dbf' );
     l_count := l_count + 1;
  END LOOP;

END;
/
