resource "docker_image" "grafana" {
  name         = "grafana/grafana:12.1.1"
  keep_locally = true
}

# Grafana guarda aquí sus usuarios y los paneles creados desde la interfaz.
resource "docker_volume" "data" {
  name = "${var.container_name}-data"
}

resource "docker_container" "grafana" {
  name    = var.container_name
  image   = docker_image.grafana.image_id
  restart = "unless-stopped"
  env = [
    "GF_SECURITY_ADMIN_PASSWORD=${var.admin_password}",
    "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/etc/grafana/dashboards/web.json",
  ]

  networks_advanced {
    name = var.public_network_name
  }

  networks_advanced {
    name = var.internal_network_name
  }

  # El navegador usa el puerto del entorno. Dentro del contenedor Grafana escucha en 3000.
  ports {
    ip       = var.bind_ip
    external = var.external_port
    internal = 3000
  }

  volumes {
    volume_name    = docker_volume.data.name
    container_path = "/var/lib/grafana"
  }

  # Al arrancar, Grafana lee este archivo y registra Prometheus en el menú de fuentes de datos.
  upload {
    file = "/etc/grafana/provisioning/datasources/prometheus.yml"
    content = templatefile("${path.module}/prometheus.yml.tftpl", {
      prometheus_name = var.prometheus_name
    })
  }

  # Este YAML indica a Grafana en qué carpeta debe buscar los dashboards al arrancar.
  upload {
    file    = "/etc/grafana/provisioning/dashboards/practica.yml"
    content = file("${path.module}/dashboards.yml")
  }

  # El JSON define qué consulta ejecuta cada panel y cómo dibuja los resultados.
  # El filtro y el número esperado salen de los mismos contenedores que declara Terraform.
  upload {
    file = "/etc/grafana/dashboards/web.json"
    content = templatefile("${path.module}/web.json.tftpl", {
      replicas        = join("|", var.web_replicas)
      total           = length(var.web_replicas)
      health_services = join("|", concat(var.web_replicas, var.health_services))
    })
  }
}
