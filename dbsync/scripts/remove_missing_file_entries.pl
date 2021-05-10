#!/usr/bin/perl
#
use strict;
use warnings;
use Getopt::Long;

my $log_dir='';
my $log_details_file='';

GetOptions(
    "log_dir=s" => \$log_dir
,   "logfile=s" => \$log_details_file
);
my $log_details_file_with_path="$log_dir/$log_details_file";
my $valid_log_details_file_with_path=$log_details_file_with_path.".valid";

print "--\n";
print "-- Remove delected entries from : $log_details_file_with_path\n";
print "--\n";

#
# Read the file
#
#
open(my $fh, '<:encoding(UTF-8)', $log_details_file_with_path)
  or die "Could not open file '$log_details_file_with_path' $!";

open(my $fh2, '>:encoding(UTF-8)', $valid_log_details_file_with_path)
  or die "Could not open file '$valid_log_details_file_with_path' $!";


my $missing_count=0;
my $found_count=0;

while (my $row = <$fh>) {
  chomp $row;
  #
  # Logfile is first field
  #
  my @fields = split "," , $row;
  my $logfile = $fields[0];

  my $log_file_with_path="$log_dir/$logfile";

  my @missing_logs;

  if (-f $log_file_with_path){
     $found_count++;
     print $fh2 $row."\n";
  }else{
     $missing_count++;
  }
}
#
# Replay log details file with the valid entry one
#
unlink $log_details_file_with_path or warn "Could not unlink $log_details_file_with_path: $!";
rename $valid_log_details_file_with_path, $log_details_file_with_path;

print "\n";
print "Logfile exists  count : $found_count\n";
print "Logfile missing count : $missing_count\n";
print "\n";

