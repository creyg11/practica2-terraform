terraform {
    required_providers {
        docker = {
        source  = "kreuzwerker/docker"
        version = "~> 3.0.2" //version hecha en clase
        }
    }
}

provider "docker" {} //No hace falta conf del provider porque lo hacemos en local 
//y no necesitamos personalizar su conexión

resource "docker_image" "flask" {
    name         = "practica2-web:dev"
    keep_locally = true //Opcional: (Boolean) If true, then the Docker image won't be deleted on destroy operation.
    build {
        context    = "${path.module}/app"
        dockerfile = "Dockerfile" //Opcional: (String) Name of the Dockerfile. Defaults to Dockerfile.
    }
}

resource "docker_container" "web" {
    name  = "practica2-web"
    image = docker_image.flask.image_id //<TIPO_DE_RECURSO>.<NOMBRE_LOCAL>.<ATRIBUTO EXPORTADO>
    # Flask depende de PostgreSQL. Como db tiene wait = true,
    # Terraform arranca la web después de que la base esté saludable.
    depends_on = [docker_container.db]
    ports {
        internal = var.web_internal_port // Puerto dentro del contenedor.
        external = var.web_external_port // Puerto publicado en tu máquina.
        ip       = var.web_bind_ip       // Dirección de tu máquina donde se publica el puerto.
    }

    //(Set of String) Environment variables to set in the form of KEY=VALUE  
    env = [
        "DB_HOST=${var.db_host}",
        "DB_PORT=${var.db_port}",
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
    }

}

resource "docker_volume" "postgres_data" {
    name = "practica2-dev-postgres-data" //Opcional: (String) The name of the Docker volume 
                                        //(will be generated if not provided).
}


//El provider kreuzwerker/docker (~> 3.0.2) no descarga imágenes de Docker Hub 
//automáticamente si no existen previamente en local.
resource "docker_image" "postgres" {
    name         = "postgres:17-bookworm"
    keep_locally = true
}

resource "docker_container" "db" {
    name  = "practica2-db"
    image = docker_image.postgres.image_id //<TIPO_DE_RECURSO>.<NOMBRE_LOCAL>.<ATRIBUTO EXPORTADO>
    
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
        host_path      = abspath("${path.module}/db/init")
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

resource "docker_network" "app_network" {
    name = "practica2-network"
    driver = "bridge"
}
