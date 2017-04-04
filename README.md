## r-cluster

A nice & easy way to create on demand R Clusters on AWS with:

- R
- Access to nodes with ssh without password for user `rstudio`

## Requirements

- [AWS Command line interface](https://aws.amazon.com/cli/)
- A valid AWS account
- `aws configure` in order to be logged in
- [jq](https://stedolan.github.io/jq/) installed
- A baked `ami`s ready with R installed (The ones used on this script will be open sourced in the future)

## Usage

- `sh create_cluster.sh`
- `sh create_rstudio.sh`

## Reference

- `sh create_cluster.sh`: This script will send all these files to an S3 bucket, and then generates the R-Cluster via de `aws cli`
- `sh create_rstudio.sh`: This script will send all these files to an S3 bucket, and then generates a R-Studio instance via de `aws cli`

## Recomendations

If you are going to bake a new AMI, make sure to delete the following files/folder

- /home/rstudio/credentials/rstudio.key
- /home/rstudio/nodes.txt
- /var/lib/cloud/instances (in order to excecute the cloud init in the future)
