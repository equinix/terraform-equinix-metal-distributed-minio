output "minio_endpoints" {
  value = formatlist("%s minio endpoint is %s", metal_device.minio-distributed-cluster[*].hostname, data.template_file.endpoint[*].rendered)
}

output "minio_access_key" {
  value = random_string.minio_access_key.result
}

output "minio_access_secret" {
  value = random_string.minio_secret_key.result
}

output "minio_region_name" {
  value = "us-east-1"
}
