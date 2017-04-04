#!/bin/bash

#download neccesary files from S3
aws s3 cp s3://r-cluster/private.key /home/rstudio/
aws s3 cp s3://r-cluster/public.key /home/rstudio/
aws s3 cp s3://r-cluster/update_nodes.sh /home/rstudio/

#generate and place nodes.txt
sh /home/rstudio/update_nodes.sh
mv nodes.txt /home/rstudio/nodes.txt

#create credentials folder & copy key
mkdir /home/rstudio/credentials
mv /home/rstudio/private.key /home/rstudio/credentials/rstudio.key

#this file is for the nodes, so we don't need it
rm /home/rstudio/public.key

#permissions
chown rstudio:rstudio /home/rstudio/nodes.txt
chown rstudio:rstudio /home/rstudio/update_nodes.sh
chown rstudio:rstudio /home/rstudio/credentials/rstudio.key
chown -R rstudio:rstudio /miroculus-data
chown -R rstudio:rstudio /home/rstudio/trap-design
chmod 0600 /home/rstudio/credentials/rstudio.key
