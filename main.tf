provider "packet" {
    auth_token = var.auth_token
}

resource "random_string" "minio_access_key" {
    length = 20
    min_upper = 1
    min_lower = 1
    min_numeric = 1
    special = false
}

resource "random_string" "minio_secret_key" {
    length = 40
    min_upper = 1
    min_lower = 1
    min_numeric = 1
    special = false
}

resource "packet_reserved_ip_block" "elastic_addresses" {
  project_id = var.project_id
  facility   = var.facility
  quantity   = var.cluster_size
}

data "template_file" "user_data_env" {
    count = var.cluster_size
    template = file("${path.module}/assets/user_data.tpl.env")
    vars = {
        minio_access_key = random_string.minio_access_key.result
        minio_secret_key = random_string.minio_secret_key.result
        minio_node_count = var.cluster_size
        minio_drive_model = var.storage_drive_model
        minio_erasure_set_drive_count = var.minio_erasure_set_drive_count
        minio_storage_class_standard = var.minio_storage_class_standard
        minio_region_name = var.minio_region_name
        minio_hostname_template = var.hostname
        minio_ipaddrs = join(" ", data.template_file.ipaddr.*.rendered)
        node_ipaddr = element(data.template_file.ipaddr.*.rendered, count.index)
        port = var.port
    }
}

data "local_file" "foo" {
    filename = "${path.module}/assets/user_data.sh"
}

resource "packet_device" "minio-distributed-cluster" {
    count = var.cluster_size
    project_id = var.project_id
    hostname = format("%s%d",var.hostname, count.index+1)
    plan = var.plan
    facilities = [var.facility]
    operating_system = var.operating_system
    billing_cycle = "hourly"
    user_data = replace(data.local_file.foo.content, "__ENVSET__", element(data.template_file.user_data_env.*.rendered, count.index))
}

resource "packet_ip_attachment" "eip_assignment" {
  count = var.cluster_size
  device_id = element(packet_device.minio-distributed-cluster.*.id, count.index)
  cidr_notation = join("/", [cidrhost(packet_reserved_ip_block.elastic_addresses.cidr_notation, count.index), "32"])
}


# ip to use
data template_file "ipaddr" {
  count = var.cluster_size
  template = "$${ip}"
  vars = {
    ip = cidrhost(packet_reserved_ip_block.elastic_addresses.cidr_notation, count.index)
  }
}

# endpoints
data "template_file" "endpoint" {
  count = var.cluster_size
  template = "http://$${ip}:$${port}"
  vars = {
    ip = element(data.template_file.ipaddr.*.rendered, count.index)
    port = var.port
  }
}

# Wait for minio to be ready
resource "null_resource" "await_minio_ready" {
  count = var.cluster_size

  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    cluster_instance_ids = join(",", packet_device.minio-distributed-cluster.*.id)
  }
  provisioner "local-exec" {
    // we retry every 5 seconds, or 12 times per minute, over 5 minutes, for 60 retries
    command = format("curl -s -f --retry 60 --retry-connrefused --connect-timeout 5 --max-time 10 --retry-delay 5 http://%s:%s/minio/health/live", element(data.template_file.ipaddr.*.rendered, count.index), var.port)
  }
}

 # provisioner "remote-exec" {
 #   when = "destroy"
 #   inline = [
 #     "head -n -${var.cluster_size+3} /etc/hosts > /tmp/tmp_file && mv -f /tmp/tmp_file /etc/hosts"
 #   ]
 # }
