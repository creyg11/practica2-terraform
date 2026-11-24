output "host" {
  description = "Alias de MinIO en la red interna que usan los clientes S3."
  value       = var.minio_host
  # Garantiza que el output sólo se resuelve cuando el contenedor ha pasado su healthcheck.
  depends_on = [docker_container.minio]
}

output "api_endpoint" {
  description = "URL del endpoint S3 de MinIO accesible desde la red interna."
  value       = "http://${var.minio_host}:${var.minio_api_port}"
  depends_on  = [docker_container.minio]
}

output "bucket" {
  description = "Bucket que contiene las fotos y la portada."
  value       = local.bucket
  # En el primer despliegue, Nginx recibe el bucket cuando la carga ha terminado.
  depends_on = [terraform_data.seed]
}
