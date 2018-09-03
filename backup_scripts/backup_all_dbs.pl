#!/usr/bin/perl
#
# $Id: //Infrastructure/GitHub/Database/backup_and_sync/backup_scripts/backup_all_dbs.pl#1 $
#
# T Dale 2015
#
use Sys::Hostname;
use strict;
use warnings;
use Switch;
use Getopt::Long;
use XML::LibXML;
use Data::Dumper;

sub fmt{
    my( $str, $color ) = @_;
    my $col_num;
    switch ($color){
        case 'red'   {$col_num=31;}
        case 'green' {$col_num=32;}
    }
    return "\033[33;${col_num}m$str\033[0m";
}
#
# 
#
my $backups_base_dir   = "";
my $using_config_file;
#
# Backup type
#
my $backup_type='';
my $rman_channels='';

GetOptions (
    "type=s"          => \$backup_type  
,   "rman_channels=s" => \$rman_channels
,   "base_dir=s"      => \$backups_base_dir
);
#
# Check inputs
#
my $full_bk  = 'FULL_BACKUP';
my $archives = 'ARCHIVELOGS_ONLY';
my $usage    = "USAGE : backup_all_dbs.ph --type <$full_bk|$archives> --rman_channels <INT> --base_dir <Base backup dir>\n\n";

my $datestring = localtime();
print "Started at $datestring\n";

print "Backup base dir         : $backups_base_dir\n";
if( !-d $backups_base_dir or $backups_base_dir eq '' ){
    print "\nBase directory error\n\n";
    print $usage;
    exit 1;
}


print "Backup type             : $backup_type\n";

if( $backup_type ne $full_bk and $backup_type ne $archives or $backup_type eq '' ){ 
    print "\ntype not in $full_bk or $archives\n\n"; 
    print $usage;
    exit 2; 
}

print "RMAN Channels           : $rman_channels\n";

if( $rman_channels eq '' ){
    print "\nrman channels not int or missing\n\n"; 
    print $usage;
    exit 3;
}  
#
# Directories
#
my $backup_scripts_dir = "$backups_base_dir/scripts";
my $config_file        = "$backup_scripts_dir/config/".hostname.".xml";

print "Looking for extra config : $config_file \n";

my $parser;
my $config_xml_doc;

if( -f $config_file ){
    print "Found, Reading xml\n";
    $parser         = XML::LibXML->new();
    $config_xml_doc = $parser->parse_file($config_file);
    $using_config_file = 1;
}else{
    print "Extra config file not found : $config_file\n";
    $using_config_file = 0;
}
print "\n";
     
my $filename       = '/etc/oratab';
my $i;
my $sync_to_str    = '';
my $zip_option_str = '';

open(my $fh , '<' , $filename)     or die "Could not open file '$filename' $!";
#
# Look through the oratab, an backup each db
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
        #
        # ASM instance?
        #
        if( $sid eq '+ASM'){
            print "ASM instance so skip\n";
        }else{
            #
            # Check if this instance is running
            #
            print sprintf( '%-10s', $sid );
            my $cmd = "ps -aef | grep -v grep | grep -i smon_$sid";
            if(`$cmd`) {
                print fmt('Running','green') . " - Start Backup \n";
                #
                # Get the sync to cmd options
                #
                if( $using_config_file ){
                    $sync_to_str = '';
                    $sync_to_str = sync_options($sid,$config_xml_doc);
                    print "Sync options : $sync_to_str \n";
                    $zip_option_str = config_option( $sid, 'compression', $config_xml_doc, 'c' );
                    print "Compression  : $zip_option_str\n";
                }else{
                    $sync_to_str    = '';
                    $zip_option_str = '';
                }
                #
                # Backup
                #
                my $bk_cmd = "$backup_scripts_dir/db_backup.sh -s $sid -b $backups_base_dir -t $backup_type -p $rman_channels" . $zip_option_str . ' ' . $sync_to_str;




                print "Running      : $bk_cmd\n\n";
                print "Logs in      : $backups_base_dir/logs\n\n";
                my $start = time;
                if(`$bk_cmd`) {
                    #
                    # Check return code
                    #
           
                    #
                    # Check backup using sql
                    #
            
                    #
                    # Backup info
                    #
                    my $duration = time - $start;
                    print "Time takes (secs)  : $duration\n\n";

                }else{
                    print fmt('BACKUP FAILED!', 'red') . "\n";
                }
            }else{
                print "DONT BACKUP $sid - Database " . fmt('NOT RUNNING', 'red') . "\n"; 
            }
        }        
    }
}

$datestring = localtime();
print "Finished at $datestring\n";

close $fh;

sub xpath{
    my ($sid,$element) = @_;
    return '/db_list/db[@name=\''.$sid.'\']/'.$element;
}

sub config_option{
    my ($sid, $element, $xml_doc, $option_when_found) = @_;
    my $option = '';
    
    $option = $xml_doc->findvalue( xpath( $sid, $element ) );

    if( $option ne '' ){ $option =  " -$option_when_found $option"; }

    return $option;
}

sub sync_options{
    my ($sid, $xml_doc) = @_;
    my $sync_str = '';

    $sync_str .=       config_option( $sid, 'rsync_option' , $xml_doc, 'r' );
    $sync_str .= ' ' . config_option( $sid, 'sync_to_1'    , $xml_doc, 'y' );
    $sync_str .= ' ' . config_option( $sid, 'sync_to_1_dir', $xml_doc, 'z' );
    $sync_str .= ' ' . config_option( $sid, 'sync_to_2'    , $xml_doc, 'g' );
    $sync_str .= ' ' . config_option( $sid, 'sync_to_2_dir', $xml_doc, 'h' );
    $sync_str .= ' ' . config_option( $sid, 'skip', $xml_doc, 'm' );

    return $sync_str;
};
