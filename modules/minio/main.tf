# La imagen oficial de minio/minio no está disponible en este entorno.
# Se usa bitnamilegacy/minio, alternativa Debian 12 idéntica en funcionalidad,
# con la versión 2024.11.7, la última publicada en ese repositorio público.
resource "docker_image" "minio" {
  name         = "bitnamilegacy/minio:2024.11.7-debian-12-r0"
  keep_locally = true
}

resource "docker_volume" "minio_data" {
  name = var.volume_name
}

resource "docker_container" "minio" {
  name    = var.container_name
  image   = docker_image.minio.image_id
  restart = var.restart

  # Bitnami MinIO arranca con /opt/bitnami/scripts/minio/run.sh por defecto.
  # Las variables de entorno que sigue la imagen son:

  env = [
    "MINIO_ROOT_USER=${var.minio_root_user}",
    "MINIO_ROOT_PASSWORD=${var.minio_root_password}",
    "MINIO_API_PORT_NUMBER=${var.minio_api_port}",
    "MINIO_CONSOLE_PORT_NUMBER=${var.minio_console_port}",
  ]

  volumes {
    volume_name    = docker_volume.minio_data.name
    container_path = "/bitnami/minio/data"
  }

  healthcheck {
    # El endpoint /minio/health/live devuelve 200 cuando el servidor está listo.
    test         = ["CMD-SHELL", "curl -f http://localhost:${var.minio_api_port}/minio/health/live || exit 1"]
    interval     = "10s"
    timeout      = "5s"
    retries      = 5
    start_period = "15s"
  }

  # Terraform espera a que el healthcheck confirme que MinIO acepta conexiones.
  wait = true

  networks_advanced {
    name = var.network_name
    # El alias permite que Flask u otros servicios resuelvan el nombre "minio"
    # dentro de la red interna sin conocer el nombre real del contenedor.
    aliases = [var.minio_host]
  }
}

locals {
  seed_script = "${path.module}/../../minio-seed.sh"
  bucket      = "seleccion"
}

# Tras el healthcheck, carga los estáticos. Se repite si cambia el contenedor,
# el script, el bucket o el nombre/contenido de una imagen.
resource "terraform_data" "seed" {
  triggers_replace = {
    container_id = docker_container.minio.id
    script_hash  = filesha256(local.seed_script)
    bucket       = local.bucket
    images       = { for path in fileset(var.images_dir, "**") : path => filesha256("${var.images_dir}/${path}") }
  }

  provisioner "local-exec" {
    command = "bash \"$SEED_SCRIPT\""
    environment = {
      SEED_SCRIPT     = abspath(local.seed_script)
      MINIO_CONTAINER = docker_container.minio.name
      IMAGES_DIR      = abspath(var.images_dir)
      IMAGES_BUCKET   = local.bucket
    }
  }
}
