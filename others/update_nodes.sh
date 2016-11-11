INSTANCE_HASH=$(curl -s http://169.254.169.254/latest/meta-data/security-groups | grep -oE "[^-]+$")
aws ec2 describe-instances --filters "Name=tag-value,Values=SlaveRCluster-"$INSTANCE_HASH | jq '.Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddress' > nodes.txt
sed 's/\"//g' nodes.txt -i nodes.txt
