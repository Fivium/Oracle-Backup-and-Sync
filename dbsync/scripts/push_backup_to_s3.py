#!/usr/bin/python3.6

from os import walk
import time, os, sys, stat, random, boto3, threading
from botocore.exceptions import ClientError

from os.path import exists

if len(sys.argv) != 2:
    print('No directory path given')
    print('Usage : push_backup_to_s3.py <DIRECTORY>')
    exit(1)
else:
    mypath = sys.argv[1]

cmd = ["ps ax | grep -i 'python.*push_backup_to_s3.py "+mypath+"' | grep -v grep"]

import subprocess

process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
myPid, err = process.communicate()

if len(myPid.splitlines()) > 1:
   #print("Running, exit now")
   exit()
else:
   print('Start')

class progressPercentage(object):

    def __init__(self, filename):
        self._lastPercentDisplayed = ''
        self._filename = filename
        self._size = float(os.path.getsize(filename))
        self._seen_so_far = 0
        self._lock = threading.Lock()

    def __call__(self, bytes_amount):
        # To simplify, assume this is hooked up to a single filename
        with self._lock:
            self._seen_so_far += bytes_amount
            percentage = (self._seen_so_far / self._size) * 100
            percentageInTens = round(percentage,2)
            if round(percentage % 10,2) == 0 and percentageInTens != self._lastPercentDisplayed:
                percentStr = str(percentageInTens).rjust(5," ")
                print("            Done : "+percentStr+"%")
                sys.stdout.flush()
                self._lastPercentDisplayed = percentageInTens

def file_age_in_minutes(pathname):
    file_age_in_seconds = time.time() - os.stat(pathname)[stat.ST_MTIME]
    return round(file_age_in_seconds/60)

def moveFileToS3(filename,s3Filename):
    print('    Move file : '+filename)
    print('           to : '+s3Filename)
    print('         Start file copy')
    try:
        copyResult = s3.meta.client.upload_file(Filename = filename, Bucket = s3BucketName, Key = s3Filename, Callback=progressPercentage(filename))
        print('         Finished')
        print('         File copy to S3 success, delete file')
        os.remove(filename)
    except ClientError as e:
        print('         ERROR, do not delete file')
        print(e)
        exit()

fileAgeMinutesToPush = 60

s3BucketName = '<YOUR_BUCKET_NAME>'
s3KeyId      = '<YOUR_S3_KEY_ID>'
s3SecretKey  = '<YOUR_S3_KEY>'

print('Moving files to S3 from '+mypath)
print('Move files over '+str(fileAgeMinutesToPush)+' minutes');

if exists(mypath):
    print('Path exists')
else:
    print('Path does not exist, exit!')
    exit()

session = boto3.Session(
    aws_access_key_id=s3KeyId,
    aws_secret_access_key=s3SecretKey,
)
s3 = session.resource('s3')

filenames = next(walk(mypath), (None, None, []))[2]  # [] if no file

for filename in filenames:
    print('')
    print(filename)
    if "backup" in filename:
        filenameWithPath = mypath+'/'+filename
        fileAgeMinutes = file_age_in_minutes(filenameWithPath)
        print('File age in minutes : '+str(fileAgeMinutes))
        if fileAgeMinutes > fileAgeMinutesToPush:
            print('Push to S3')
            filenameSplit = filename.split('_')
            s3FilenameWithPath = filenameSplit[0]+'/'+filenameSplit[3]+'/'+filename
            moveFileToS3(filenameWithPath,s3FilenameWithPath)
        else:
            print('Ignore for now, file not old enough')
    else:
       print('Ignore, not a backup piece')
