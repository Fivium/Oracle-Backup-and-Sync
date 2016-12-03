#!/bin/bash
#
# $Id: //Infrastructure/Database/scripts/profiles/aliases_base.sh#2 $
#
# Aliases
#
PROFILE_DIR="$HOME/profiles"
export PROFILE_DIR
alias sql='. $PROFILE_DIR/sql'

alias sqlplus='rlwrap -i -c -f $PROFILE_DIR/sqlplus.dict sqlplus'
alias rman='rlwrap -i -c -f $PROFILE_DIR/rman.dict $ORACLE_HOME/bin/rman'
alias rmanc='rlwrap -i -c -f $PROFILE_DIR/rman.dict $ORACLE_HOME/bin/rman target=/'
alias lsnrs='lsnrctl status'
alias pl='$PROFILE_DIR/create_db_aliases.pl;$HOME/db_aliases.sh'
echo "--"
echo "--"
echo "Aliases :"
echo "  sql   - sqlplus / as sysdba - TAB auto complete on"
echo "  rmanc - rman target=/"
echo "  lsnrs - lsnrctl status"
echo "  pl    - show all profiles and aliases"
echo "Databases :"
