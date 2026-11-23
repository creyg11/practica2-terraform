resource "docker_image" "postgres" {
  name         = "postgres:17-bookworm"
  keep_locally = true
}

resource "docker_volume" "postgres_data" {
  name = var.volume_name
}

resource "docker_container" "db" {
  name    = var.container_name
  image   = docker_image.postgres.image_id
  restart = var.restart

  env = [
    "POSTGRES_DB=${var.postgres_db}",
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}"
  ]

  volumes { //Seria del compose: - postgres_data:/var/lib/postgresql/data
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  volumes { //Seria del compose: - ./db/init:/docker-entrypoint-initdb.d:ro
    host_path      = abspath(var.init_dir)
    container_path = "/docker-entrypoint-initdb.d"
    read_only      = true
  }

  # Terraform espera a que el healthcheck con pg_isready confirme que
  # PostgreSQL acepta conexiones antes de dar el contenedor por creado.
  wait = true

  healthcheck {
    test = [
      "CMD",
      "pg_isready",
      "-h", "127.0.0.1",
      "-p", tostring(var.db_port),
      "-U", var.postgres_user,
      "-d", var.postgres_db
    ]

    interval     = "5s"
    timeout      = "3s"
    retries      = 5
    start_period = "10s"
  }

  networks_advanced {
    name    = var.network_name
    aliases = [var.db_host]
  }


}
