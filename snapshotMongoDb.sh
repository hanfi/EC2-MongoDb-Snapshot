#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

This script stops the mongo databases from writing, and creates a EBS snapshot. to assure the integrity.

This is an example of the AMI User or Role policy to use:
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

Works with IAM Roles

Credentials can be set as Environment Variables :
	$ export AWS_ACCESS_KEY_ID=YourAccessKey
	$ export AWS_SECRET_ACCESS_KEY=YourSecretKey


Or use ~/.aws/config file, the default account will b used.

OPTIONS:
   -h      Show this message
   -k      AWS Access Key
   -s      AWS Secret Key
   -f      Force Config {CMD_PARAMS, CONF_FILE, IAM_ROLE, ENV_VAR}
   -d      Snapshot Description
EOF
}

while getopts “ht:k:s:f:d:” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    k)
      ACCESS_KEY_ID=$OPTARG
      ;;
    s)
      SECRET_ACCESS_KEY=$OPTARG
      ;;
    f)
      FORCE_CONF=$OPTARG
      if ! [[ "$FORCE_CONF" =~ ^(CMD_PARAMS|CONF_FILE|IAM_ROLE|ENV_VAR)$ ]]; then
        echo "-f wrong parameter : use CMD_PARAMS, CONF_FILE, IAM_ROLE, ENV_VAR"
        exit 1
      fi
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


#Check if config is forced to use a specific Method
if [[ -n "$FORCE_CONF" ]]; then
  CRED_SOURCE=$FORCE_CONF

#Check Command params
elif [[ -n "$ACCESS_KEY_ID" && -n "$SECRET_ACCESS_KEY" ]]; then
  CRED_SOURCE="CMD_PARAMS"
  
#Check Config file Presence
elif [ -f ~/.aws/config ]; then
  CRED_SOURCE="CONF_FILE"

#Check IAM Role Presence We suppose that curl is installed 
elif [ $(echo "$(curl --silent --write-out "\n%{http_code}\n" http://169.254.169.254/latest/meta-data/iam/info/)" | sed -n '$p') = 200 ]; then
  CRED_SOURCE="IAM_ROLE"

#Check Env vars presence 
elif [[ -n "$AWS_ACCESS_KEY_ID" && -n "$AWS_SECRET_ACCESS_KEY" ]]; then
  CRED_SOURCE="ENV_VAR"

fi

echo "$CRED_SOURCE Credentials will be used to perfom AWS actions"

#Create the Config file to use if needed
case $CRED_SOURCE in
  "CMD_PARAMS")
    AWS_ACCESS_KEY_ID=ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY=SECRET_ACCESS_KEY
    CONF_CREATED="true"
    ;;
  "ENV_VAR")
    AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
    CONF_CREATED="true"
    ;;
  *)
    CONF_CREATED="false"
    ;;
esac

if [[ CONF_CREATED = "true" ]]; then

  echo "Creation of ~/.aws/config"

  : ${AWS_ACCESS_KEY_ID:?"\$AWS_ACCESS_KEY_ID must be set in ~/.aws/config, as Environment Variable Or as command Param -k"}
  : ${AWS_SECRET_ACCESS_KEY:?"\$AWS_SECRET_ACCESS_KEY must be set in ~/.aws/config, as Environment Variable Or as command Param -s"}
  : ${REGION:?"\$REGION must be set in ~/.aws/config, as Environment Variable Or as command Param -r"}

  mkdir ~/.aws/

  echo "[default]
  aws_access_key_id=$AWS_ACCESS_KEY_ID
  aws_secret_access_key=$AWS_SECRET_ACCESS_KEY
  region=$REGION
  output=json" > ~/.aws/config
fi


echo $CONF_CREATED
# #Check if Mongo is in PATH
# command -v mongo >/dev/null 2>&1 || { echo >&2 "I require mongo but it's not installed or not in PATH.  Aborting."; exit 1; }

# #install pip and aws-cli if not present 
# command -v pip >/dev/null 2>&1 || { echo >&2 "pip is not installed !!! begin PIP install"; sudo apt-get install python-pip -y;}
# command -v aws >/dev/null 2>&1 || { echo >&2 "AWSCLI is not installed !!! begin AWSCLI install"; sudo pip install awscli;}



# # Create Snapshot description
# if [ "$DESCRIPTION" = "" ];then

# 	DATE=$(date -u "+%F-%H%M%S")
# 	DESCRIPTION="backup-$DATE"
# fi

# CONF_CREATED="false"


# #Lock the database
# mongo admin --eval "var databaseNames = db.getMongo().getDBNames(); for (var i in databaseNames) { printjson(db.getSiblingDB(databaseNames[i]).getCollectionNames()) }; printjson(db.fsyncLock());"

# # DO backup
# SNAP_ID=$(aws ec2 create-snapshot --volume-id $(aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=$(ec2metadata --instance-id) --query Volumes[*].VolumeId --output=text) --description "$DESCRIPTION" --query SnapshotId --output=text)

# #info
# echo "Snapshot_id = $SNAP_ID
# Description = $DESCRIPTION"


# #wait for the snapshot to complete
# while [ $(aws ec2 describe-snapshots --snapshot-ids $SNAP_ID --query Snapshots[*].State --output=text) != "completed" ]
# do
# 	echo "wating for snapshot $SNAP_ID to complete ..."
# 	sleep 5
# done

# echo "snapshot $SNAP_ID completed !!!"

# # Unlock the database
# mongo admin --eval "printjson(db.fsyncUnlock());"

# #Delete the configuration file if it was created buy the script
# if [ "$CONF_CREATED" = "true" ]; then

# 	sudo rm -rf ~/.aws/config

# fi 