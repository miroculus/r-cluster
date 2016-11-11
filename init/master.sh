#!/bin/bash

#download neccesary files from S3
aws s3 cp s3://r-cluster /home/rstudio/ --recursive
#run script to generate nodes.txt
sh /home/rstudio/update_nodes.sh
#clone our coude
git clone git@github.com:miroculus/trap-design.git /home/rstudio/trap-design

mv home/rstudio/key.pem /home/rstudio/credentials/rstudio.key
mv nodes.txt /home/rstudio/nodes.txt

chown rstudio:rstudio /home/rstudio/nodes.txt
chown rstudio:rstudio /home/rstudio/update_nodes.sh
chown rstudio:rstudio /home/rstudio/credentials/rstudio.key
chown -R rstudio:rstudio /miroculus-data
chown -R rstudio:rstudio /site-library
chown -R rstudio:rstudio /home/rstudio/trap-design

chmod 0600 /home/rstudio/credentials/rstudio.key
