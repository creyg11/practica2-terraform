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

resource "docker_network" "app_network" {
  name   = "practica2-network"
  driver = "bridge"
}

module "postgres" {
  source = "../../modules/postgres"

  container_name    = "practica2-db"
  volume_name       = "practica2-dev-postgres-data"
  network_name      = docker_network.app_network.name
  init_dir          = "${path.module}/../../db/init"
  db_host           = var.db_host
  db_port           = var.db_port
  postgres_db       = var.postgres_db
  postgres_user     = var.postgres_user
  postgres_password = var.postgres_password
}

module "web" {
  source = "../../modules/web"

  container_name    = "practica2-web"
  image_name        = "practica2-web:dev"
  build_context     = "${path.module}/../../app"
  dockerfile        = "Dockerfile"
  network_name      = docker_network.app_network.name
  web_bind_ip       = var.web_bind_ip
  web_internal_port = var.web_internal_port
  web_external_port = var.web_external_port

  # Los outputs host hacen que Flask espere a sus servicios antes de arrancar.
  env = [
    "DB_HOST=${module.postgres.host}",
    "DB_PORT=${var.db_port}",
    "POSTGRES_DB=${var.postgres_db}",
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}",
  ]
}
