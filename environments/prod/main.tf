terraform {
    required_providers {
        docker = {
        source  = "kreuzwerker/docker"
        // El provider 3.0.2 usado en clase enviaba peticiones con la API 1.41.
        // Nuestro Docker Engine 29.1.3 exige al menos la API 1.44, por eso usamos 4.6.0.
        version = "~> 4.6.0"
        }
    }
}

provider "docker" {} //No hace falta conf del provider porque lo hacemos en local 
//y no necesitamos personalizar su conexión

resource "docker_image" "flask" {
    name         = "practica2-web:prod"
    keep_locally = true //Opcional: (Boolean) If true, then the Docker image won't be deleted on destroy operation.
    build {
        context    = "${path.module}/../../app"
        dockerfile = "Dockerfile.prod" # Instala el cliente Redis y arranca Flask con Gunicorn.
    }
}

resource "docker_container" "web" {
    # Dev y prod pueden usar docker_container.web porque cada entorno tiene su propio estado.
    # En el mismo Docker, cada contenedor necesita un nombre único.
    name  = "practica2-prod-web"
    image = docker_image.flask.image_id //<TIPO_DE_RECURSO>.<NOMBRE_LOCAL>.<ATRIBUTO EXPORTADO>
    restart = "unless-stopped"
    # Equivale a service_healthy en Compose: db y redis tienen wait = true.
    # Terraform crea la web cuando ambos han pasado sus comprobaciones de salud.
    depends_on = [docker_container.db, docker_container.redis]
    # Cada contenedor puede escuchar en 5000. En la misma IP del host, cada entorno publica un puerto distinto.
    ports {
        internal = var.web_internal_port // Puerto dentro del contenedor.
        external = var.web_external_port // Puerto publicado en tu máquina.
        ip       = var.web_bind_ip       // Dirección de tu máquina donde se publica el puerto.
    }

    # En producción Flask usa Redis para el listado de jugadores y comprueba la caché en /health.
    env = [
        "APP_ENV=production",
        "DB_HOST=${var.db_host}",
        "DB_PORT=${var.db_port}",
        "REDIS_HOST=${var.redis_host}",
        "REDIS_PORT=${var.redis_port}",
        "POSTGRES_DB=${var.postgres_db}",
        "POSTGRES_USER=${var.postgres_user}",
        "POSTGRES_PASSWORD=${var.postgres_password}"
    ]

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
        name = docker_network.app_network.name
        aliases = ["web"]
    }

}

resource "docker_volume" "postgres_data" {
    name = "practica2-prod-postgres-data" //Opcional: (String) The name of the Docker volume
                                        //(will be generated if not provided).
}


// Gestionamos la imagen de PostgreSQL y la referenciamos desde el contenedor db.
resource "docker_image" "postgres" {
    name         = "postgres:17-bookworm"
    keep_locally = true
}

resource "docker_container" "db" {
    name  = "practica2-prod-db"
    image = docker_image.postgres.image_id //<TIPO_DE_RECURSO>.<NOMBRE_LOCAL>.<ATRIBUTO EXPORTADO>
    restart = "unless-stopped"
    
    env = [
        "POSTGRES_DB=${var.postgres_db}",
        "POSTGRES_USER=${var.postgres_user}",
        "POSTGRES_PASSWORD=${var.postgres_password}"
    ]
    
    volumes{ //Seria del compose: - postgres_data:/var/lib/postgresql/data
        volume_name    = docker_volume.postgres_data.name
        container_path = "/var/lib/postgresql/data"
    }

    volumes { //Seria del compose: - ./db/init:/docker-entrypoint-initdb.d:ro
        host_path      = abspath("${path.module}/../../db/init")
        container_path = "/docker-entrypoint-initdb.d"
        read_only      = true
    }

    # Terraform espera a que el healthcheck con pg_isready confirme que
    # PostgreSQL acepta conexiones antes de dar el contenedor por creado.
    wait = true

    healthcheck {
        test = [
        "CMD",
        "pg_isready",
        "-h", "127.0.0.1",
        "-p", tostring(var.db_port),
        "-U", var.postgres_user,
        "-d", var.postgres_db
        ]

        interval     = "5s"
        timeout      = "3s"
        retries      = 5
        start_period = "10s"
    }

    networks_advanced {
        name    = docker_network.app_network.name
        aliases = [var.db_host]
    }


}

resource "docker_image" "redis" {
    name="redis:7.4-alpine"
    keep_locally = true
}

resource "docker_container" "redis" {
    name    = "practica2-prod-redis"
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
        test = ["CMD-SHELL", "redis-cli ping | grep -qx PONG"]
        interval     = "5s"
        timeout      = "3s"
        retries      = 5
        start_period = "5s"
    }

    # Terraform da Redis por creado cuando el healthcheck pasa.
    wait = true

    networks_advanced {
        name    = docker_network.app_network.name
        # Docker resuelve este alias dentro de la red de prod. Flask lo recibe como REDIS_HOST.
        aliases = [var.redis_host]
    }
}

resource "docker_network" "app_network" {
    name = "practica2-prod-network"
    driver = "bridge"
}
