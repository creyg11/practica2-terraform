resource "docker_image" "nginx" {
  name         = "nginx:1.30-alpine"
  keep_locally = true
}

resource "docker_container" "load_balancer" {
  name    = var.container_name
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  # En esta red Nginx puede resolver los nombres Docker de las réplicas.
  networks_advanced {
    name = var.public_network_name
  }

  networks_advanced {
    name = var.internal_network_name
  }

  upload {
    # Docker copia al contenedor la configuración que Terraform genera con la plantilla.
    file = "/etc/nginx/conf.d/default.conf"

    # El output del módulo web proporciona los nombres y establece la dependencia.
    content = templatefile("${path.module}/nginx-lb.conf.tftpl", {
      minio_host_port = var.minio_host_port
      images_bucket   = var.images_bucket
      nombres         = var.nombres_replicas
      puerto_web      = var.web_internal_port
      puerto_lb       = var.nginx_port
    })
  }

  ports {
    # Docker reenvía el puerto del host al puerto donde escucha Nginx.
    internal = var.nginx_port
    external = var.nginx_port
    ip       = var.nginx_bind_ip
  }
}
