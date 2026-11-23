resource "docker_image" "redis" {
  name         = "redis:7.4-alpine"
  keep_locally = true
}

resource "docker_container" "redis" {
  name    = var.container_name
  image   = docker_image.redis.image_id
  restart = "unless-stopped"

  # La imagen cambia al usuario Linux redis cuando el comando empieza por redis-server.
  # Como aquí empieza por sh, indicamos el usuario para arrancar con sus permisos.
  user = "redis"

  # El proveedor rechaza elementos vacíos en command. La shell convierte '' en el
  # argumento vacío de --save que desactiva las instantáneas, como en el Compose.
  # Con «--appendonly no» se desactiva el registro AOF. exec sustituye la shell por Redis
  # para que Docker le envíe directamente la señal de parada.
  command = ["sh", "-c", "exec redis-server --port ${var.redis_port} --save '' --appendonly no"]

  # Monta /data en memoria. La cadena vacía usa las opciones por defecto.
  tmpfs = {
    "/data" = ""
  }

  healthcheck {
    test         = ["CMD-SHELL", "redis-cli ping | grep -qx PONG"]
    interval     = "5s"
    timeout      = "3s"
    retries      = 5
    start_period = "5s"
  }

  # Terraform da Redis por creado cuando el healthcheck pasa.
  wait = true

  networks_advanced {
    name = var.network_name
    # Docker resuelve este alias dentro de la red de prod. Flask lo recibe como REDIS_HOST.
    aliases = [var.redis_host]
  }
}
