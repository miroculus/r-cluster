## r-cluster

A nice & easy way to create on demand EMR Clusters on AWS with:

- R
- Access to nodes with ssh without password for user `rstudio`

## Requirements

- [AWS Command line interface](https://aws.amazon.com/cli/)
- A valid AWS account
- `aws configure` in order to be logged in

## Usage

- `sh create_cluster.sh`

## Reference

- `sh create_cluster.sh`: This script will send all these files to an S3 bucket, and then generates the R-Cluster via de `aws cli`
