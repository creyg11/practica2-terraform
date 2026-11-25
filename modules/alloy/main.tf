resource "docker_image" "alloy" {
  name         = "grafana/alloy:v1.22.0"
  keep_locally = true
}

resource "docker_volume" "positions" {
  name = "${var.container_name}-positions"
}

resource "docker_container" "alloy" {
  name    = var.container_name
  image   = docker_image.alloy.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = var.internal_network_name
  }

  # Alloy usa la API de Docker para descubrir contenedores y leer su salida.
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }

  # La imagen guarda aquí hasta dónde ha leído de cada contenedor para reanudar la recogida.
  volumes {
    volume_name    = docker_volume.positions.name
    container_path = "/var/lib/alloy/data"
  }

  upload {
    file = "/etc/alloy/config.alloy"
    content = templatefile("${path.module}/config.alloy.tftpl", {
      network_name = var.internal_network_name
      loki_url     = var.loki_url
    })
  }
}
