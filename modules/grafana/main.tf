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
  env = concat([
    "GF_SECURITY_ADMIN_PASSWORD=${var.admin_password}",
    # Las cookies de localhost se comparten entre puertos. Cada Grafana usa su propio nombre de cookie.
    "GF_AUTH_LOGIN_COOKIE_NAME=${var.container_name}_session",
    "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH=/etc/grafana/dashboards/web.json",
    ], var.alert_email == null ? [] : [
    "GF_SMTP_ENABLED=true",
    "GF_SMTP_HOST=${var.alert_email.host}",
    "GF_SMTP_FROM_ADDRESS=${var.alert_email.from}",
    "GF_SMTP_USER=${var.alert_email.user}",
    "GF_SMTP_PASSWORD__FILE=/run/secrets/grafana_smtp_password",
    "GF_SMTP_STARTTLS_POLICY=MandatoryStartTLS",
    "ALERT_MAIL_TO=${var.alert_email.to}",
  ])

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

  # Grafana lee el secreto desde este montaje. Terraform solo maneja la ruta.
  dynamic "volumes" {
    for_each = nonsensitive(var.alert_email != null) ? [1] : []
    content {
      host_path      = abspath(var.alert_email.password_file)
      container_path = "/run/secrets/grafana_smtp_password"
      read_only      = true
    }
  }

  # Grafana registra Prometheus para métricas y, si el entorno lo incluye, Loki para logs.
  upload {
    file = "/etc/grafana/provisioning/datasources/prometheus.yml"
    content = templatefile("${path.module}/datasources.yml.tftpl", {
      prometheus_name = var.prometheus_name
      loki_url        = var.loki_url
    })
  }

  # Solo prod carga la regla. El destinatario se añade cuando el entorno configura SMTP.
  dynamic "upload" {
    for_each = var.enable_web_alert ? [1] : []
    content {
      file = "/etc/grafana/provisioning/alerting/web.yml"
      content = templatefile("${path.module}/web-alert.yml.tftpl", {
        replicas  = join("|", var.web_replicas)
        send_mail = nonsensitive(var.alert_email != null)
      })
    }
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
      # El panel de alertas solo aparece en el entorno que carga la regla.
      enable_web_alert = var.enable_web_alert
    })
  }
}
