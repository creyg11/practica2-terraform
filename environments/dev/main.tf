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
  name   = "practica2-dev-public-network"
  driver = "bridge"
}

# Red interna aislada: bloquea salida a Internet y publicación de puertos.
# Permite únicamente tráfico entre contenedores y resolución DNS interna (127.0.0.11).
resource "docker_network" "internal_network" {
  name     = "practica2-dev-internal-network"
  driver   = "bridge"
  internal = true
}

module "postgres" {
  source = "../../modules/postgres"

  container_name    = "practica2-db"
  volume_name       = "practica2-dev-postgres-data"
  network_name      = docker_network.internal_network.name
  init_dir          = "${path.module}/../../db/init"
  db_host           = var.db_host
  db_port           = var.db_port
  postgres_db       = var.postgres_db
  postgres_user     = var.postgres_user
  postgres_password = var.postgres_password
}

module "minio" {
  source = "../../modules/minio"

  images_dir = "${path.module}/../../app/static/images"

  container_name      = "practica2-dev-minio"
  volume_name         = "practica2-dev-minio-data"
  network_name        = docker_network.internal_network.name
  minio_host          = var.minio_host
  minio_api_port      = var.minio_api_port
  minio_console_port  = var.minio_console_port
  minio_root_user     = var.minio_root_user
  minio_root_password = var.minio_root_password
}

module "web" {
  source = "../../modules/web"

  container_name    = "practica2-web"
  image_name        = "practica2-web:dev"
  build_context     = "${path.module}/../../app"
  dockerfile        = "Dockerfile"
  network_name      = docker_network.internal_network.name
  replica_count     = var.web_replica_count
  aliases           = ["web"]
  web_internal_port = var.web_internal_port

  # Los outputs host hacen que Flask espere a sus servicios antes de arrancar.
  env = [
    "DB_HOST=${module.postgres.host}",
    "DB_PORT=${var.db_port}",
    "POSTGRES_DB=${var.postgres_db}",
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}",
  ]
}

module "load_balancer" {
  source = "../../modules/load_balancer"

  minio_host_port       = "${module.minio.host}:${var.minio_api_port}"
  images_bucket         = module.minio.bucket
  container_name        = "practica2-dev-nginx" 
  public_network_name   = docker_network.public_network.name
  internal_network_name = docker_network.internal_network.name
  web_internal_port     = var.web_internal_port
  nginx_port            = var.nginx_port
  nginx_bind_ip         = var.nginx_bind_ip

  depends_on            = [module.web]
}

module "observability" {
  source = "../../modules/observability"

  name_prefix           = "practica2-dev"
  public_network_name   = docker_network.public_network.name
  internal_network_name = docker_network.internal_network.name
  nginx_container_name  = "practica2-dev-nginx"
  bind_ip               = var.nginx_bind_ip
  prometheus_port       = 9091

  # PostgreSQL y las réplicas de dev conservan los nombres de la primera práctica.
  enable_extended_metrics       = true
  docker_socket_gid             = var.docker_socket_gid
  db_dsn                        = "postgresql://${replace(urlencode(var.postgres_user), "+", "%20")}:${replace(urlencode(var.postgres_password), "+", "%20")}@${module.postgres.host}:${var.db_port}/${replace(urlencode(var.postgres_db), "+", "%20")}?sslmode=disable"
  additional_container_patterns = ["practica2-db", "practica2-web-*"]
  web_container_name            = "practica2-web"

  depends_on = [module.load_balancer]
}
