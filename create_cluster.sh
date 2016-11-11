#!/bin/bash

# SETTING VARIABLES
aws_zone='us-west-2'
keypair='r-studio'
slave_nodes=4
ami_master_node='ami-6d47e40d'
ami_slave_node='ami-5f41e23f'
master_node_instance_type='m4.xlarge'
slave_node_instance_type='m4.xlarge'
cluster_name=RCluster-$(date +"%Y%m%d%H%M")
master_instance_script='init/master.sh'
s3_bucket='r-cluster'

echo "Creating cluster " $cluster_name

# CREATING INFRASTRUCTURE 1/2
echo "Setting AWS zone..."
aws configure set region $aws_zone

echo "Coping Files..."
aws s3 cp cert s3://r-cluster --recursive
aws s3 cp others s3://r-cluster --recursive

echo "[INFO][1/2] 1.Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --instance-tenancy default | jq .Vpc.VpcId)
VPC_ID="$(echo $VPC_ID | sed 's/\"//g')"
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$cluster_name
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

echo "[INFO][1/2] 2.Creating Public Subnet for VPC:" $VPC_ID
SUBNET_PUBLIC_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.0.0/24 | jq .Subnet.SubnetId)
SUBNET_PUBLIC_ID="$(echo $SUBNET_PUBLIC_ID | sed 's/\"//g')"
aws ec2 create-tags --resources $SUBNET_PUBLIC_ID --tags Key=Name,Value=Public_$cluster_name

echo "[INFO][1/2] 3.Creating Private Subnet for VPC:" $VPC_ID
SUBNET_PRIVATE_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 | jq .Subnet.SubnetId)
SUBNET_PRIVATE_ID="$(echo $SUBNET_PRIVATE_ID | sed 's/\"//g')"
aws ec2 create-tags --resources $SUBNET_PRIVATE_ID --tags Key=Name,Value=Private_$cluster_name

echo "[INFO][1/2] 4.Create and Attach Internet gateway to VPC:" $VPC_ID
INTERNET_GATEWAY_ID=$(aws ec2 create-internet-gateway | jq .InternetGateway.InternetGatewayId)
INTERNET_GATEWAY_ID="$(echo $INTERNET_GATEWAY_ID | sed 's/\"//g')"
aws ec2 attach-internet-gateway --internet-gateway-id $INTERNET_GATEWAY_ID --vpc-id $VPC_ID

echo "[INFO][1/2] 5.Create Route Table"
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID | jq .RouteTable.RouteTableId)
ROUTE_TABLE_ID="$(echo $ROUTE_TABLE_ID | sed 's/\"//g')"
aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $INTERNET_GATEWAY_ID

echo "[INFO][1/2] 6.Associate Route Table with Subnet"
aws ec2 associate-route-table --route-table-id $ROUTE_TABLE_ID --subnet-id $SUBNET_PUBLIC_ID

echo "Creating infrastructure: Done! Now we're going to create the instances..."

# CREATING INSTANCES 2/2
echo "[INFO][2/2] 1.Creating Secutity Group for Public/Master Node"
SECURITY_GROUP_PUBLIC=$(aws ec2 create-security-group --group-name PublicSG_$cluster_name --description "Public Security Group for "$cluster_name --vpc-id $VPC_ID | jq .GroupId)
SECURITY_GROUP_PUBLIC="$(echo $SECURITY_GROUP_PUBLIC | sed 's/\"//g')"

echo "[INFO][2/2] 2.Creating Secutity Group for Private/Salves Nodes"
SECURITY_GROUP_PRIVATE=$(aws ec2 create-security-group --group-name PrivateSG_$cluster_name --description "Public Security Group for "$cluster_name --vpc-id $VPC_ID | jq .GroupId)
SECURITY_GROUP_PRIVATE="$(echo $SECURITY_GROUP_PRIVATE | sed 's/\"//g')"

echo "[INFO][2/2] 3.Setting Roules for Public Security Group: "$SECURITY_GROUP_PUBLIC
# INBOUND - external
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_PUBLIC --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_PUBLIC --protocol tcp --port 80 --cidr 0.0.0.0/0
# INBOUND - internal
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_PUBLIC --protocol tcp --port 11000-11999 --source-group $SECURITY_GROUP_PRIVATE
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_PUBLIC --protocol udp --port 11000-11999 --source-group $SECURITY_GROUP_PRIVATE

# OUTBOUND - external
aws ec2 authorize-security-group-egress --group-id $SECURITY_GROUP_PUBLIC --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-egress --group-id $SECURITY_GROUP_PUBLIC --protocol tcp --port 22 --source-group $SECURITY_GROUP_PRIVATE
# # OUTBOUND - internal
aws ec2 authorize-security-group-egress --group-id $SECURITY_GROUP_PUBLIC --protocol tcp --port 11000-11999 --source-group $SECURITY_GROUP_PRIVATE
aws ec2 authorize-security-group-egress --group-id $SECURITY_GROUP_PUBLIC --protocol udp --port 11000-11999 --source-group $SECURITY_GROUP_PRIVATE

echo "[INFO][2/2] 4.Setting Roules for Private Security Group: "$SECURITY_GROUP_PRIVATE
# INBOUND
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_PRIVATE --protocol tcp --port 22 --source-group $SECURITY_GROUP_PUBLIC
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_PRIVATE --protocol tcp --port 11000-11999 --source-group $SECURITY_GROUP_PUBLIC
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_PRIVATE --protocol udp --port 11000-11999 --source-group $SECURITY_GROUP_PUBLIC
# # OUTBOUND
aws ec2 authorize-security-group-egress --group-id $SECURITY_GROUP_PRIVATE --protocol tcp --port 11000-11999 --source-group $SECURITY_GROUP_PUBLIC
aws ec2 authorize-security-group-egress --group-id $SECURITY_GROUP_PRIVATE --protocol udp --port 11000-11999 --source-group $SECURITY_GROUP_PUBLIC

echo "[INFO][2/2] 5.Creating Slave Node(s)"
SLAVE_NODE_IDS=$(aws ec2 run-instances --image-id $ami_slave_node --count $slave_nodes --instance-type $master_node_instance_type --key-name $keypair --security-group-ids $SECURITY_GROUP_PRIVATE --subnet-id $SUBNET_PRIVATE_ID | jq '.Instances[] | "\(.InstanceId)"')
SLAVE_NODE_IDS="$(echo $SLAVE_NODE_IDS | sed 's/\"//g')"
# We are going to tag the instances, but since they could be more than one, we are going to iterate
for CURRENT_NODE in $(echo $SLAVE_NODE_IDS | tr " " "\n");
   do aws ec2 create-tags --resources $CURRENT_NODE --tags Key=Name,Value=Slave$cluster_name;
done

echo "[INFO][2/2] 6.Creating Master Node"
MASTER_NODE_ID=$(aws ec2 run-instances --image-id $ami_master_node --count 1 --instance-type $slave_node_instance_type --key-name $keypair --security-group-ids $SECURITY_GROUP_PUBLIC --subnet-id $SUBNET_PUBLIC_ID --associate-public-ip-address --user-data file://$master_instance_script | jq '.Instances[] | "\(.InstanceId)"')
MASTER_NODE_ID="$(echo $MASTER_NODE_ID | sed 's/\"//g')"
#Tag Master Node
aws ec2 create-tags --resources $MASTER_NODE_ID --tags Key=Name,Value=Master$cluster_name

MASTER_NODE_DNS=$(aws ec2 describe-instances --instance-ids $MASTER_NODE_ID | jq '.Reservations[].Instances[].PublicDnsName')
MASTER_NODE_DNS="$(echo $MASTER_NODE_DNS | sed 's/\"//g')"

echo "Cluster Ready!"
echo "To ssh: ssh -i 'r-studio.pem' ubuntu@"$MASTER_NODE_DNS
echo "To web access: http://"$MASTER_NODE_DNS" user:rstudio / password:rstudio"
