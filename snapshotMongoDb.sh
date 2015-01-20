#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

This script stops the mongo databases from writing, and creates a EBS snapshot. to assure the integrity.

This is an example of the AMI User policy to use:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "000000000000000",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSnapshot",
        "ec2:DescribeSnapshots",
        "ec2:DescribeVolumes"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}


Credentials can be set as Environment Variables :
	$ export AWS_ACCESS_KEY_ID=YourAccessKey
	$ export AWS_SECRET_ACCESS_KEY=YourSecretKey
	$ export AWS_DEFAULT_REGION=us-west-1

OPTIONS:
   -h      Show this message
   -k      AWS Access Key
   -s      AWS Secret Key
   -r      AWS Region
   -d      Snapshot Description
EOF
}


AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
REGION=$AWS_DEFAULT_REGION


while getopts “ht:k:s:r:d:” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    k)
      AWS_ACCESS_KEY_ID=$OPTARG
      ;;
    s)
      AWS_SECRET_ACCESS_KEY=$OPTARG
      ;;
    r)
      REGION=$OPTARG
      ;;
    d)
      DESCRIPTION=$OPTARG
      ;;  
    ?)
      usage
      exit
    ;;
  esac
done


#Check if Mongo is in PATH
command -v mongo >/dev/null 2>&1 || { echo >&2 "I require mongo but it's not installed or not in PATH.  Aborting."; exit 1; }

#install pip and aws-cli if not present 
command -v pip >/dev/null 2>&1 || { echo >&2 "pip is not installed !!! begin PIP install"; sudo apt-get install python-pip -y;}
command -v aws >/dev/null 2>&1 || { echo >&2 "AWSCLI is not installed !!! begin AWSCLI install"; sudo pip install awscli;}



# Create Snapshot description
if [ "$DESCRIPTION" = "" ];then

	DATE=$(date -u "+%F-%H%M%S")
	DESCRIPTION="backup-$DATE"
fi

CONF_CREATED="false"

#verify if config already exists ToDo better use AWS-ec2-role
if [ ! -f ~/.aws/config ]; then

: ${AWS_ACCESS_KEY_ID:?"\$AWS_ACCESS_KEY_ID must be set in ~/.aws/config, as Environment Variable Or as command Param -k"}
: ${AWS_SECRET_ACCESS_KEY:?"\$AWS_SECRET_ACCESS_KEY must be set in ~/.aws/config, as Environment Variable Or as command Param -s"}
: ${REGION:?"\$REGION must be set in ~/.aws/config, as Environment Variable Or as command Param -r"}

mkdir ~/.aws/

echo "[default]
aws_access_key_id=$AWS_ACCESS_KEY_ID
aws_secret_access_key=$AWS_SECRET_ACCESS_KEY
region=$REGION
output=json" > ~/.aws/config

CONF_CREATED="true"

fi

#Lock the database
mongo admin --eval "var databaseNames = db.getMongo().getDBNames(); for (var i in databaseNames) { printjson(db.getSiblingDB(databaseNames[i]).getCollectionNames()) }; printjson(db.fsyncLock());"

# DO backup
SNAP_ID=$(aws ec2 create-snapshot --volume-id $(aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$(ec2metadata --instance-id) --query Volumes[*].VolumeId --output=text) --description "$DESCRIPTION" --query SnapshotId --output=text)

#info
echo "Snapshot_id = $SNAP_ID
Description = $DESCRIPTION"


#wait for the snapshot to complete
while [ $(aws ec2 describe-snapshots --snapshot-ids $SNAP_ID --query Snapshots[*].State --output=text) != "completed" ]
do
	echo "wating for snapshot $SNAP_ID to complete ..."
	sleep 5
done

echo "snapshot $SNAP_ID completed !!!"

# Unlock the database
mongo admin --eval "printjson(db.fsyncUnlock());"

#Delete the configuration file if it was created buy the script
if [ "$CONF_CREATED" = "true" ]; then

	sudo rm -rf ~/.aws/config

fi 