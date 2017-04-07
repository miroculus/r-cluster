## r-cluster

A nice & easy way to create on demand R Clusters on AWS with:

- R
- Access to nodes with ssh without password for user `rstudio`
- Ready to use [dopar](https://cran.r-project.org/web/packages/doParallel/index.html)

## Requirements

- [AWS Command line interface](https://aws.amazon.com/cli/)
- A logged AWS user
- [jq](https://stedolan.github.io/jq/)
- A baked `ami`s ready with R installed (The ones used on this script will be open sourced in the future)
- A `public.key` and `private.ket` under `/cert`

## Usage

- `sh create_cluster.sh`
- `sh create_rstudio.sh`

## Update

- `sh update_nodes.sh`: to update the node ip list, e.g. when cluster is restarted.

## Reference

- `sh create_cluster.sh`: This script will send all these files to an S3 bucket, and then generates the R-Cluster via de `aws cli`
- `sh create_rstudio.sh`: This script will send all these files to an S3 bucket, and then generates a R-Studio instance via de `aws cli`

## Recomendations

If you are going to bake a new AMI, make sure to delete the following files/folder

- /home/rstudio/credentials/rstudio.key
- /home/rstudio/nodes.txt
- /var/lib/cloud/instances (in order to force the excecution of the cloud init script)

## More Recomendations

Since the process of bootstraping a node with a lot of R packages is really slow and unstable (and impossible when creating slave nodes without internet), we've decided to bake our own `ami`s with packages already shipped.
