--
-- $Id: //Infrastructure/Database/scripts/profiles/start_asm.sql#1 $
--

select instance_name from v$instance;
select systimestamp from dual;
SET LINESIZE  145
SET PAGESIZE  9999
SET VERIFY    off

COLUMN group_name             FORMAT a20           HEAD 'Disk Group|Name'
COLUMN sector_size            FORMAT 99,999        HEAD 'Sector|Size'
COLUMN block_size             FORMAT 99,999        HEAD 'Block|Size'
COLUMN allocation_unit_size   FORMAT 999,999,999   HEAD 'Allocation|Unit Size'
COLUMN state                  FORMAT a11           HEAD 'State'
COLUMN type                   FORMAT a6            HEAD 'Type'
COLUMN total_mb               FORMAT 999,999,999   HEAD 'Total Size (MB)'
COLUMN used_mb                FORMAT 999,999,999   HEAD 'Used Size (MB)'
COLUMN pct_used               FORMAT 999.99        HEAD 'Pct. Used'

break on report on disk_group_name skip 1

compute sum label "Grand Total: " of total_mb used_mb on report

SELECT
    name                                     group_name
  , sector_size                              sector_size
  , block_size                               block_size
  , allocation_unit_size                     allocation_unit_size
  , state                                    state
  , type                                     type
  , total_mb                                 total_mb
  , (total_mb - free_mb)                     used_mb
  , ROUND((1- (free_mb / decode(total_mb,0,1,total_mb)))*100, 2)  pct_used
FROM
    v$asm_diskgroup
ORDER BY
    name;

COLUMN disk_group_name    FORMAT a10           HEAD 'Disk Group Name'
COLUMN disk_path          FORMAT a10           HEAD 'Disk Path'
COLUMN reads              FORMAT 9,999,999,999 HEAD 'Reads'
COLUMN writes             FORMAT 999,999,999   HEAD 'Writes'
COLUMN read_errs          FORMAT 999,999       HEAD 'Read|Errors'
COLUMN write_errs         FORMAT 999,999       HEAD 'Write|Errors'
COLUMN read_time          FORMAT 999.99        HEAD 'Avg Read|Time MS'
COLUMN write_time         FORMAT 999.99        HEAD 'Avg Write|Time MS'
COLUMN mb_read            FORMAT 999,999,999   HEAD 'MB|Read'
COLUMN mb_written         FORMAT 999,999,999   HEAD 'MB|Written'

break on report on disk_group_name skip 2

compute sum label ""              of reads writes read_errs write_errs mb_read mb_written on disk_group_name
compute sum label "Grand Total: " of reads writes read_errs write_errs mb_read mb_written on report

SELECT
    a.name                  disk_group_name
  , b.path                  disk_path
  , b.reads                 reads
  , b.writes                writes
  , b.read_errs             read_errs
  , b.write_errs            write_errs
  , round((b.read_time/decode(b.reads,0,1,b.reads))*1000,2)    read_time
  , round((b.write_time/decode(b.writes,0,1,b.writes))*1000,2) write_time
  , b.bytes_read/1048576    mb_read
  , b.bytes_written/1048576 mb_written
FROM
    v$asm_diskgroup a JOIN v$asm_disk b USING (group_number)
ORDER BY
    a.name;
