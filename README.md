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
In the `terraform.tfvars` file you will need to add your Packet API token next to `auth_token` and Packet Project ID next to `project_id` variables in order to deploy the Minio cluster. You can also modify other variables such as the instance type, datacenter location, operating system, and a specific drive model that you wish to use for Minio as it is recommended to use homogeneous drives and servers. Specifying a drive model is not required for the script to run and if you leave the string empty, the script will use any/all drives in the server but this is not recommended. To find the drive models in the instance type, deploy a single instance and run the following command which will list all the drives along with the model name if they are spinning disks.

```
lsblk -d -o name,size,model,rota
```

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
In order to use this Minio to upload objects via Terraform, to a ***public*** bucket on Minio, you will need to create a bucket (`public` is the name of the bucket in this example). To create the bucket login to one of the minio servers through SSH and run the following. The command to add a host to the minio client is in the format of `mc config host add $ALIAS $MINIO_ENDPOINT $MINIO_ACCESS_KEY $MINIO_SECRET_KEY`. You can also add the following as part of the automation in the terraform script.

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

## Load Balancing your Minio cluster

It is recommended to load balance the traffic to your minion server endpoints through a single endpoint. This can be done through a DNS record that points to your minio servers or you could even utilize a Packet Elastic IP and announce it through BGP on all the minio servers to achieve ECMP load balancing.
