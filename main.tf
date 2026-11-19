terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2" //version hecha en clase
    }
  }
}

provider "docker" {} //No hace falta conf del provider porque lo hacemos en local 
//y no necesitamos personalizar su conexión

resource "docker_image" "flask" {
  name         = "practica2-web:dev"
  keep_locally = true //Opcional: (Boolean) If true, then the Docker image won't be deleted on destroy operation.
  build {
    context    = "${path.module}/app"
    dockerfile = "Dockerfile" //Opcional: (String) Name of the Dockerfile. Defaults to Dockerfile.
  }
}

resource "docker_container" "web" {
  name  = "practica2-web"
  image = docker_image.flask.image_id

  ports {
    internal = var.web_internal_port // Puerto dentro del contenedor.
    external = var.web_external_port // Puerto publicado en tu máquina.
    ip       = var.web_bind_ip       // Dirección de tu máquina donde se publica el puerto.
  }

  //(Set of String) Environment variables to set in the form of KEY=VALUE  
  env = [
    "DB_HOST=${var.db_host}",
    "DB_PORT=${var.db_port}",
    "POSTGRES_DB=${var.postgres_db}",
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}"
  ]

  healthcheck {
    test = [
      "CMD",
      "python",
      "-c",
      "import urllib.request; urllib.request.urlopen('http://${var.web_bind_ip}:${var.web_internal_port}/health', timeout=8)"
    ]

    interval     = "10s"
    timeout      = "9s"
    retries      = 3
    start_period = "15s"
  }

}

