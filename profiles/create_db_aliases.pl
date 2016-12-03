#!/usr/bin/perl
#
# $Id: //Infrastructure/Database/scripts/profiles/create_db_aliases.pl#2 $
#
# T Dale 2014
#
use strict;
use warnings;
use Switch;
sub fmt{
    my( $str, $color ) = @_;
    my $col_num;
    switch ($color){
        case 'red'   {$col_num=31;}
        case 'green' {$col_num=32;}
    }
    return "\033[33;${col_num}m$str\033[0m";
}

my $filename     = '/etc/oratab';
my $ora_home     = '/home/oracle';
my $aliases_file = "$ora_home/db_aliases.sh";
my $profile_dir  = "$ora_home/profiles";
my $aliases_base = "$profile_dir/aliases_base.sh";
my $i;

open(my $fh , '<' , $filename)     or die "Could not open file '$filename' $!";
open(my $fh2, '>>', $aliases_file) or die "Could not open file '$aliases_file' $!";
#
# Start the aliases file
#
system("cp $aliases_base $aliases_file");
#
# Look through the alertlog, then adding new aliases for each db
#
while (my $row = <$fh>) {
    chomp $row;
    #
    # Look for oracle sids
    #
    if ($row =~ /.*:\/.*:[Y,N]/){
        #
        # Get sid, oracle home and auto start info
        #
        my ($sid,$oracle_home,$auto_start) = split /:/, $row;
        my $profile_name = "db".++$i;
        #
        # Check if this instance is running
        #
        my $running_chk = 'NOT RUNNING';
        my $color       = 'red';
        my $cmd         = "ps -aef | grep -v grep | grep -i smon_$sid";
        if(`$cmd`) {
            $running_chk = 'RUNNING';
            $color       = 'green';
        }
        $running_chk = fmt( $running_chk, $color );
        print $fh2 "echo \"  ".sprintf( '%-5s', $profile_name )." - set env for ".sprintf( '%-10s', $sid )." - $running_chk\" \n";
        $cmd = "alias $profile_name='. $profile_dir/db_profile $sid'";
        print $fh2 "$cmd\n";
    }
}
print $fh2 "echo \"--\"\n";
system("chmod 700 $aliases_file");
close $fh;
close $fh2;

