.DEFAULT_GOAL := help
ENV ?= dev
ifneq ($(ENV),dev)
ifneq ($(ENV),prod)
$(error ENV debe ser dev o prod)
endif
endif

TF = terraform -chdir=environments/$(ENV)
DEMO = bash scripts/demo.sh
PRUEBAS = arquitectura estado redes replicas db persistencia cache caida-redis minio metricas logs failover alerta coach-add coach-remove
DOCKER = docker-ps docker-stop docker-start docker-restart docker-rm docker-logs
export C

.PHONY: help init validate plan apply up up-all destroy recrear-db demo check $(PRUEBAS) $(DOCKER)

help:
	@printf '%s\n' 'DEFENSA' \
	  '  make demo              Presentación guiada con Enter (q para salir)' \
	  '  make check             Salud y reparto en dev y prod' \
	  '  make arquitectura      Módulos y estados Terraform por entorno' \
	  '  make estado            Contenedores, salud y URLs de ambos entornos' \
	  '  make redes             Redes y puertos publicados' \
	  '  make replicas          Réplicas que atienden /jugadores' \
	  '  make db                PostgreSQL y volumen de datos' \
	  '  make persistencia       Alta → recreación de PostgreSQL → comprobación en web → baja' \
	  '  make coach-add         Insertar el entrenador de prueba (ENV=dev/prod)' \
	  '  make recrear-db        Recrear el contenedor PostgreSQL y conservar el volumen' \
	  '  make coach-remove      Eliminar el entrenador de prueba (ENV=dev/prod)' \
	  '  make cache             Listado servido por Redis en prod' \
	  '  make caida-redis         Parar Redis en prod, ver PostgreSQL en la web y recuperar la caché' \
	  '  make minio             Foto del bucket servida por Nginx' \
	  '  make metricas          Generar tráfico y ver CPU y memoria por réplica' \
	  '  make logs              Seguir una petición desde Nginx hasta Loki' \
	  '  make failover          Parar una réplica de prod y recuperarla' \
	  '  make alerta            Provocar la alerta real de prod y recuperarla' \
	  'DOCKER EN DIRECTO (ENV=dev por defecto)' \
	  '  make docker-ps ENV=prod                   Listar nombres, estado y puertos' \
	  '  make docker-logs C=nginx ENV=prod         Ver las últimas 30 líneas' \
	  '  make docker-stop C=web-2 ENV=prod         Parar una réplica' \
	  '  make docker-start C=web-2 ENV=prod        Arrancar el mismo contenedor' \
	  '  make docker-restart C=db ENV=dev          Reiniciar PostgreSQL' \
	  '  make docker-rm C=db ENV=dev               Eliminar un contenedor ya parado' \
	  '  Tras eliminar db, make recrear-db ENV=dev la recupera con el mismo volumen.' \
	  '  Para otros servicios eliminados, make apply ENV=dev permite revisar y aplicar el plan.' \
	  'TERRAFORM' \
	  '  make init | validate | plan | apply | up | destroy ENV=dev' \
	  '  make up-all            Desplegar dev y prod con sus tfvars' \
	  '  ENV=dev por defecto. replicas, db, minio, metricas y logs admiten ENV=prod.'

init validate plan apply destroy:
	$(TF) $@

up: init
	$(TF) apply

recrear-db:
	@$(DEMO) $@ $(ENV)

up-all:
	$(MAKE) up ENV=dev
	$(MAKE) up ENV=prod

demo:
	@$(DEMO)

check $(PRUEBAS) $(DOCKER):
	@$(DEMO) $@ $(ENV)
