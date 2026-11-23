resource "docker_image" "flask" {
  name         = var.image_name
  keep_locally = true
  build {
    context    = var.build_context
    dockerfile = var.dockerfile
  }
}

resource "docker_container" "web" {
  # Dev y prod pueden usar docker_container.web porque cada entorno tiene su propio estado.
  # En el mismo Docker, cada contenedor necesita un nombre único.
  name = var.container_name
  # Flask muestra este hostname para identificar el contenedor que sirvió la página.
  hostname = var.container_name
  image    = docker_image.flask.image_id
  restart  = var.restart
  # Cada contenedor puede escuchar en 5000. En la misma IP del host, cada entorno publica un puerto distinto.
  ports {
    internal = var.web_internal_port // Puerto dentro del contenedor.
    external = var.web_external_port // Puerto publicado en tu máquina.
    ip       = var.web_bind_ip       // Dirección de tu máquina donde se publica el puerto.
  }

  env = var.env

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

  networks_advanced {
    name    = var.network_name
    aliases = var.aliases
  }

}
