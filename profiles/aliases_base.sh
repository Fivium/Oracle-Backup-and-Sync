#!/bin/bash
#
# Aliases
#
PROFILE_DIR="$HOME/profiles"
export PROFILE_DIR
export PERL5LIB=${ORACLE_HOME}/perl/lib

export PATH ORACLE_BASE ORACLE_HOME

alias sql='. $PROFILE_DIR/sql'

alias sqlplus='rlwrap -i -c -f $PROFILE_DIR/sqlplus.dict sqlplus'
alias rman='rlwrap -i -c -f $PROFILE_DIR/rman.dict $ORACLE_HOME/bin/rman'
alias rmanc='rlwrap -i -c -f $PROFILE_DIR/rman.dict $ORACLE_HOME/bin/rman target=/'
alias lsnrs='lsnrctl status'
#alias pl='clear;$PROFILE_DIR/create_db_aliases.pl;$HOME/db_aliases.sh'
alias pl='. ~/.bash_profile'
echo "--"
echo "--"
echo "Aliases :"
echo "  sql   - sqlplus / as sysdba - TAB auto complete on"
echo "  rmanc - rman target=/"
echo "  lsnrs - lsnrctl status"
echo "  pl    - show all profiles and aliases"
echo "Databases :"
