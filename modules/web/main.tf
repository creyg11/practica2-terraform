resource "docker_image" "flask" {
  name         = var.image_name
  keep_locally = true
  build {
    context    = var.build_context
    dockerfile = var.dockerfile
  }
}

resource "docker_container" "web" {
  # count.index empieza en 0. Sumamos 1 para obtener nombres como practica2-web-1.
  count = var.replica_count
  name  = "${var.container_name}-${count.index + 1}"
  # Flask muestra este hostname en /jugadores para identificar qué réplica respondió.
  hostname = "${var.container_name}-${count.index + 1}"
  image    = docker_image.flask.image_id
  restart  = var.restart

  env = var.env

  # Docker comprueba /health desde el interior de cada réplica.
  healthcheck {
    test = [
      "CMD",
      "python",
      "-c",
      "import urllib.request; urllib.request.urlopen('http://127.0.0.1:${var.web_internal_port}/health', timeout=8)"
    ]

    interval     = "10s"
    timeout      = "9s"
    retries      = 3
    start_period = "15s"
  }

  # Las réplicas escuchan en la red Docker. El puerto del host lo publica Nginx.
  networks_advanced {
    name    = var.network_name
    aliases = var.aliases
  }
}
