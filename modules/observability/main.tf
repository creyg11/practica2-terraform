resource "docker_image" "nginx_exporter" {
  name         = "nginx/nginx-prometheus-exporter:1.4.0"
  keep_locally = true
}

resource "docker_image" "prometheus" {
  name         = "prom/prometheus:v2.55.1"
  keep_locally = true
}

resource "docker_volume" "prometheus_data" {
  name = "${var.name_prefix}-prometheus-data"
}

# Traduce /stub_status de Nginx a /metrics para Prometheus (solo en internal_network).
resource "docker_container" "nginx_exporter" {
  name    = "${var.name_prefix}-nginx-exporter"
  image   = docker_image.nginx_exporter.image_id
  restart = "unless-stopped"

  # Le indica al contenedor a qué nombre DNS interno y puerto tiene que pedir los datos.
  command = [
    "--nginx.scrape-uri=http://${var.nginx_container_name}:8090/stub_status"
  ]

  networks_advanced {
    name = var.internal_network_name
  }
}

# Recolecta y almacena las series temporales cada 5 segundos.
resource "docker_container" "prometheus" {
  name    = "${var.name_prefix}-prometheus"
  image   = docker_image.prometheus.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = var.internal_network_name
  }

  upload {
    file = "/etc/prometheus/prometheus.yml"
    content = templatefile("${path.module}/prometheus.yml.tftpl", {
      nginx_exporter_host     = "${var.name_prefix}-nginx-exporter"
      enable_extended_metrics = var.enable_extended_metrics
      postgres_exporter_host  = "${var.name_prefix}-postgres-exporter"
      redis_exporter_host     = "${var.name_prefix}-redis-exporter"
      telegraf_host           = "${var.name_prefix}-telegraf"
    })
  }

  volumes {
    volume_name    = docker_volume.prometheus_data.name
    container_path = "/prometheus"
  }


  depends_on = [docker_container.nginx_exporter]

}

// Imagen del exporter que consulta PostgreSQL y expone sus métricas para Prometheus.
resource "docker_image" "postgres_exporter" {
  count        = var.enable_extended_metrics ? 1 : 0
  name         = "prometheuscommunity/postgres-exporter:v0.16.0"
  keep_locally = true
}

// Imagen del exporter que consulta Redis y expone sus métricas para Prometheus.
resource "docker_image" "redis_exporter" {
  count        = var.enable_extended_metrics ? 1 : 0
  name         = "oliver006/redis_exporter:v1.67.0"
  keep_locally = true
}

# Prod activa las métricas extendidas. El mismo módulo en dev omite esta imagen y su contenedor.
resource "docker_image" "telegraf" {
  count        = var.enable_extended_metrics ? 1 : 0
  name         = "telegraf:1.38.1"
  keep_locally = true
}

// Ejecuta el exporter de PostgreSQL solo cuando están activadas las métricas extendidas.
resource "docker_container" "postgres_exporter" {
  count   = var.enable_extended_metrics ? 1 : 0
  name    = "${var.name_prefix}-postgres-exporter"
  image   = docker_image.postgres_exporter[0].image_id
  restart = "unless-stopped"
  # Evita que procesos del contenedor adquieran privilegios adicionales durante la ejecución.
  security_opts = ["no-new-privileges:true"]

  # El DSN permite al exporter conectarse a la base de datos que debe monitorizar.
  env = [
    "DATA_SOURCE_NAME=${var.db_dsn}"
  ]

  networks_advanced {
    name = var.internal_network_name
  }
}

// Ejecuta el exporter de Redis solo cuando están activadas las métricas extendidas.
resource "docker_container" "redis_exporter" {
  count   = var.enable_extended_metrics ? 1 : 0
  name    = "${var.name_prefix}-redis-exporter"
  image   = docker_image.redis_exporter[0].image_id
  restart = "unless-stopped"
  # Evita que procesos del contenedor adquieran privilegios adicionales durante la ejecución.
  security_opts = ["no-new-privileges:true"]

  # Le indica al exporter dónde está Redis dentro de la red interna de Docker.
  command = [
    "--redis.addr=redis://${var.cache_container_name}:6379"
  ]

  networks_advanced {
    name = var.internal_network_name
  }
}

# Docker mide los recursos de cada contenedor. Telegraf consulta esas medidas y
# las ofrece a Prometheus con el nombre de la réplica que las produjo.
resource "docker_container" "telegraf" {
  count   = var.enable_extended_metrics ? 1 : 0
  name    = "${var.name_prefix}-telegraf"
  image   = docker_image.telegraf[0].image_id
  restart = "unless-stopped"

  # 65534 es un usuario sin privilegios. El grupo se obtiene del socket del host
  # y llega desde terraform.tfvars de prod para que ese usuario pueda conectarse.
  user          = "65534:${var.docker_socket_gid}"
  security_opts = ["no-new-privileges:true"]
  capabilities {
    drop = ["ALL"]
  }

  # Arranca directamente el agente con el archivo que genera Terraform más abajo.
  entrypoint = ["telegraf"]
  command    = ["--config", "/etc/telegraf/telegraf.conf"]

  # Prometheus llega al puerto 9273 por esta red usando el nombre del contenedor.
  networks_advanced {
    name = var.internal_network_name
  }

  # Terraform escribe el prefijo del entorno en el filtro de contenedores.
  upload {
    file = "/etc/telegraf/telegraf.conf"
    content = templatefile("${path.module}/telegraf.conf.tftpl", {
      name_prefix = var.name_prefix
    })
  }

  # El socket comunica el agente con la API de Docker, la misma que usa docker stats.
  # read_only protege el montaje; los permisos de la API dependen del acceso al socket.
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }
}
