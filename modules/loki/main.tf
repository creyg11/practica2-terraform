resource "docker_image" "loki" {
  name         = "grafana/loki:3.5.3"
  keep_locally = true
}

resource "docker_volume" "data" {
  name = "${var.container_name}-data"
}

resource "docker_container" "loki" {
  name    = var.container_name
  image   = docker_image.loki.image_id
  restart = "unless-stopped"

  # Loki responde 200 cuando sus componentes están listos para atender peticiones.
  healthcheck {
    test         = ["CMD", "wget", "-q", "-O", "/dev/null", "http://127.0.0.1:3100/ready"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 3
    start_period = "45s"
  }

  # Grafana consulta Loki por el nombre del contenedor y el puerto interno 3100.
  networks_advanced {
    name = var.internal_network_name
  }

  # La configuración incluida en la imagen guarda el índice y los bloques de logs en /loki.
  # El volumen conserva ambos cuando se recrea el contenedor.
  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/loki"
  }
}
