terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      # La versión de clase usaba la API 1.41. Docker Engine 29.1.3 exige al menos la 1.44.
      version = "~> 4.6.0"
    }
  }
}

# Los módulos heredan la conexión con el Docker local.
provider "docker" {}

# Red pública (DMZ): única red con salida exterior y publicación de puertos al host
resource "docker_network" "public_network" {
  name   = "practica2-prod-public-network"
  driver = "bridge"
}

# Red interna aislada: bloquea salida a Internet y publicación de puertos.
# Permite únicamente tráfico entre contenedores y resolución DNS interna (127.0.0.11).
resource "docker_network" "internal_network" {
  name     = "practica2-prod-internal-network"
  driver   = "bridge"
  internal = true
}

module "postgres" {
  source = "../../modules/postgres"

  container_name    = "practica2-prod-db"
  volume_name       = "practica2-prod-postgres-data"
  network_name      = docker_network.internal_network.name
  init_dir          = "${path.module}/../../db/init"
  db_host           = var.db_host
  db_port           = var.db_port
  postgres_db       = var.postgres_db
  postgres_user     = var.postgres_user
  postgres_password = var.postgres_password
  restart           = "unless-stopped"
}

module "redis" {
  source = "../../modules/redis"

  container_name = "practica2-prod-redis"
  network_name   = docker_network.internal_network.name
  redis_host     = var.redis_host
  redis_port     = var.redis_port
}

module "minio" {
  source = "../../modules/minio"

  images_dir = "${path.module}/../../app/static/images"

  container_name      = "practica2-prod-minio"
  volume_name         = "practica2-prod-minio-data"
  network_name        = docker_network.internal_network.name
  minio_host          = var.minio_host
  minio_api_port      = var.minio_api_port
  minio_console_port  = var.minio_console_port
  minio_root_user     = var.minio_root_user
  minio_root_password = var.minio_root_password
  restart             = "unless-stopped"
}

module "web" {
  source = "../../modules/web"

  container_name    = "practica2-prod-web"
  image_name        = "practica2-web:prod"
  build_context     = "${path.module}/../../app"
  dockerfile        = "Dockerfile.prod"
  network_name      = docker_network.internal_network.name
  replica_count     = var.web_replica_count
  web_internal_port = var.web_internal_port
  aliases           = ["web"]
  restart           = "unless-stopped"

  # Los outputs host hacen que Flask espere a sus servicios antes de arrancar.
  env = [
    "APP_ENV=production",
    "REDIS_HOST=${module.redis.host}",
    "REDIS_PORT=${var.redis_port}",
    "DB_HOST=${module.postgres.host}",
    "DB_PORT=${var.db_port}",
    "POSTGRES_DB=${var.postgres_db}",
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}",
  ]
}

module "load_balancer" {
  source = "../../modules/load_balancer"

  minio_host_port = "${module.minio.host}:${var.minio_api_port}"
  images_bucket   = module.minio.bucket

  container_name        = "practica2-prod-nginx"
  public_network_name   = docker_network.public_network.name
  internal_network_name = docker_network.internal_network.name
  nombres_replicas      = module.web.nombres_replicas
  web_internal_port     = var.web_internal_port
  nginx_port            = var.nginx_port
  nginx_bind_ip         = var.nginx_bind_ip
}
