# packet-distributed-minio

# Minio Distributed on Packet with Terraform
packet-distributed-minio is a [Terraform](http://terraform.io) template that will deploy [Minio](http://min.io) distributed on [Packet](http://packet.com) baremetal. MinIO is a high performance object storage server compatible with Amazon S3. Minio is a great option for Packet users that want to have easily accessible S3 compatible object storage as Packet offers instance types with storage options including SATA SSDs, NVMe SSDs, and high capacity SATA HDDs.

## Install Terraform 
Terraform is just a single binary.  Visit their [download page](https://www.terraform.io/downloads.html), choose your operating system, make the binary executable, and move it into your path. 
 
Here is an example for **macOS**: 
```bash 
curl -LO https://releases.hashicorp.com/terraform/0.12.25/terraform_0.12.25_darwin_amd64.zip 
unzip terraform_0.12.25_darwin_amd64.zip
chmod +x terraform 
sudo mv terraform /usr/local/bin/ 
``` 
 
## Download this project
To download this project, run the following command:

```bash
git clone https://github.com/enkelprifti98/packet-distributed-minio.git
cd packet-distributed-minio
```

## Initialize Terraform 
Terraform uses modules to deploy infrastructure. In order to initialize the modules your simply run: `terraform init`. This should download modules into a hidden directory `.terraform` 
 
## Modify your variables 
We've added *.tfvars to the .gitignore file but you can copy the template with:

*`cp vars.template terraform.tfvars`

In the `terraform.tfvars` file you will need to modify the following variables:

..*`auth_token` - This is your Packet API Key.
..*`project_id` - This is your Packet Project ID.
..*`ssh_private_key_path` - Path to your private SSH key for accessing servers you deploy on Packet.

[Learn about Packet API Keys and Project IDs](https://www.packet.com/developers/docs/api/)

Optional variables are:

..*`plan` - We're using **s3.xlarge.x86** servers by default.
..*`operating_system` - This install is verified for **Ubuntu 20.04**.
..*`facility` - Where would you like these servers deployed, we're using **DC13**.
..*`cluster_size` - How many servers in the cluster? We default to **4**.
..*`hostname` - Naming scheme for your Minio nodes, default is **minio-storage-node**.
..*`storage_drive_model` - You'll have to know the storage drive model in advance of your deployment so Minio only uses intended drives (mixing drives is not recommened). We're using **HGST** here since that's the current 8TB drive in the s3.xlarge.x86.
..*`minio_region_name` - Name for your cluster, default is **us-east-1**.

The following are pretty important when setting up your cluster as they define how performant (particularly when using HDDs) and how protected your data is. You should consider how large the files you are storing are, the smaller the file (eg 1MB and lower), it's likely you would use a lower erasure set size to gain more performance, though this consideration is based on the type of disks you are using.
..*`minio_erasure_set_drive_count` - This defines how many drives comprise an erasure set. It should be a multiple of the cluster size. We're going with **8**, which with our default settings means we will have 6 sets of 8 drives.
..*`minio_storage_class_standard` - This defines how many parity drives will be used in an erasure set, we're setting this to **EC:2**. With our default settings, that means for 8 drives in an erasue set, 2 will be dedicated to parity.

You can see a specific Packet servers model by deploying an instance with Ubuntu and running:

```
lsblk -d -o name,size,model,rota
```

Or you can contact the support team at support.packet.com.

To view all available plans, facilities, and operating_systems - you can use our [Packet CLI](https://github.com/packethost/packet-cli) or make a call to the respective API endpoints directly. [API Docs](https://www.packet.com/developers/api/).

If you wish to modify the filesystem to be used along with the parent path of the directories where the drives will be mounted, you can do so in the `user_data.sh` bash script in the /templates folder in this repository. The relevant bash variables are `DATA_BASE` for the parent directory path and `FILESYSTEM_TYPE` for the filesystem you wish to use.

## Deploy the Minio cluster
```bash
terraform apply --auto-approve
```
Once this is complete you should get output similar to this:
```
Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

Outputs:

minio_access_key = Xe245QheQ7Nwi20dxsuF
minio_access_secret = 9g4LKJlXqpe7Us4MIwTPluNyTUJv4A5T9xVwwcZh
minio_endpoints = [
  "node1 minio endpoint is http://147.75.65.29:9000",
  "node2 minio endpoint is http://147.75.39.227:9000",
  "node3 minio endpoint is http://147.75.66.53:9000",
  "node4 minio endpoint is http://147.75.194.101:9000",
]
minio_region_name = us-east-1
```

## Sample S3 Upload
In order to use this Minio setup to upload objects via Terraform, to a ***public*** bucket on Minio, you will need to create a bucket (`public` is the name of the bucket in this example). To create the bucket login to one of the minio servers through SSH and run the following. The command to add a host to the minio client is in the format of `mc config host add $ALIAS $MINIO_ENDPOINT $MINIO_ACCESS_KEY $MINIO_SECRET_KEY`. You can also add the following as part of the automation in the terraform script.

```
mc config host add minio http://127.0.0.1:9000 Xe245QheQ7Nwi20dxsuF 9g4LKJlXqpe7Us4MIwTPluNyTUJv4A5T9xVwwcZh
mc mb minio/public
mc policy set public minio/public
```

To upload files through terraform you can add the following code to the main.tf file:
```
provider "aws" {
    region = "us-east-1"
    access_key = "Xe245QheQ7Nwi20dxsuF"
    secret_key = "9g4LKJlXqpe7Us4MIwTPluNyTUJv4A5T9xVwwcZh"
    skip_credentials_validation = true
    skip_metadata_api_check = true
    skip_requesting_account_id = true
    s3_force_path_style = true
    endpoints {
        s3 = "http://147.75.65.29:9000"
    }   
}

resource "aws_s3_bucket_object" "object" {
    bucket = "public"
    key = "my_file_name.txt"
    source = "path/to/my_file_name.txt"
    etag = filemd5("path/to/my_file_name.txt")
}
```

We're using the AWS Terraform Provider here since Minio is an S3 compliant storage solution.


## Load Balancing your Minio cluster

It is recommended to load balance the traffic to your minion server endpoints through a single endpoint. This can be done through a DNS record that points to your minio servers or you could even utilize a Packet Elastic IP and announce it through BGP on all the minio servers to achieve ECMP load balancing.
