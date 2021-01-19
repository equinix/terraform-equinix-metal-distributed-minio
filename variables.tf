variable "auth_token" {
    description = "Equinix Metal API Key"
    type = string
}

variable "project_id" {
    description = "Equinix Metal Project ID"
    type = string
}

variable "facility" {
    description = "Your storage clusters location."
    default = "dc13"
    type = string
}

variable "operating_system" {
    description = "Operating System for your servers, this install is verified for Ubuntu 20.04"
    default = "ubuntu_20_04"
    type = string
}

variable "plan"{
    description = "The server type to deploy, we're using our dense storage config (96TB HDD)."
    default = "s3.xlarge.x86"
    type = string
}

variable "cluster_size" {
    description = "Amount of servers in the Minio cluster."
    default = 4
}

variable "hostname" {
    description = "Naming scheme for Minio nodes."
    default = "minio-storage-node"
}

variable "port" {
  description = "Port minio will listen on"
  default = 9000
}

variable "public" {
  description = "Listen on public IPv4"
  default = true
}

variable "storage_drive_model" {
    description = "Storage device model you're using for Minio."
    default = "HGST"
}

variable "minio_erasure_set_drive_count" {
    description = "This defines how many drives comprise an erasure set. It should be a multiple of the cluster size. We're going with 8, which with our default settings means we will have 6 sets of 8 drives."
    default = "8"
}

variable "minio_storage_class_standard" {
    description = "This defines how many parity drives will be used in an erasure set, we're setting this to 2. With our default settings, that means for 8 drives in an erasue set, 2 will be dedicated to parity."
    default = "EC:2"
}

variable "minio_region_name" {
    description = "Give your distributed cluster a name!"
    default = "us-east-1"
}
