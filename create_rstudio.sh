#!/bin/bash

# SETTING VARIABLES
aws_zone='us-west-2'
keypair='r-studio'
ami_master_node='ami-cc54fcac'
master_node_instance_type='m4.xlarge'
vm_name=RStudio-$(date +"%Y%m%d%H%M")

echo "Creating Rstudio VM " $vm_name

# CREATING INFRASTRUCTURE 1/2
echo "Setting AWS zone..."
aws configure set region $aws_zone

# CREATING INSTANCES 2/2
echo "[INFO][2/2] 1.Creating Secutity Group"
SECURITY_GROUP_PUBLIC=$(aws ec2 create-security-group --group-name PublicSG_$vm_name --description "Public Security Group for "$vm_name | jq .GroupId)
SECURITY_GROUP_PUBLIC="$(echo $SECURITY_GROUP_PUBLIC | sed 's/\"//g')"

echo "[INFO][2/2] 2.Setting Roules for Public Security Group: "$SECURITY_GROUP_PUBLIC
# INBOUND - external
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_PUBLIC --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_PUBLIC --protocol tcp --port 80 --cidr 0.0.0.0/0

echo "[INFO][2/2] 3.Creating VM"
MASTER_NODE_ID=$(aws ec2 run-instances --image-id $ami_master_node --count 1 --instance-type $master_node_instance_type --key-name $keypair --security-group-ids $SECURITY_GROUP_PUBLIC  --associate-public-ip-address | jq '.Instances[] | "\(.InstanceId)"')
MASTER_NODE_ID="$(echo $MASTER_NODE_ID | sed 's/\"//g')"
#Tag Master Node
aws ec2 create-tags --resources $MASTER_NODE_ID --tags Key=Name,Value=$vm_name

MASTER_NODE_DNS=$(aws ec2 describe-instances --instance-ids $MASTER_NODE_ID | jq '.Reservations[].Instances[].PublicDnsName')
MASTER_NODE_DNS="$(echo $MASTER_NODE_DNS | sed 's/\"//g')"

echo "Cluster Ready!"
echo "To ssh: ssh -i '"$keypair".pem' ubuntu@"$MASTER_NODE_DNS
echo "To web access: http://"$MASTER_NODE_DNS" user:rstudio / password:rstudio"
