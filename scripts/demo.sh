#!/usr/bin/env bash
# Desde la raíz: make demo. Cada paso también se puede ejecutar con make <nombre>.
set -euo pipefail
cd "$(dirname "$0")/.."
env=${2:-dev}
case "$env" in dev|prod) ;; *) exit 2 ;; esac
prod=practica2-prod
stopped=()
coach_env=''
coach_name='Luis de la Fuente Castillo'

pause() {
    local answer
    printf '\n%s [Enter / q para salir] ' "$1"
    read -r answer || exit 0
    if [[ $answer == q ]]; then exit 0; fi
}

# Anotamos solo contenedores inicialmente activos. También se recuperan al salir con Ctrl+C.
restore() {
    if (( ${#stopped[@]} )); then
        printf 'Restaurando %s\n' "${stopped[*]}"
        docker start "${stopped[@]}"
        stopped=()
    fi
}
cleanup() {
    restore
    if [[ -n $coach_env ]]; then
        echo "Retirando el entrenador añadido por esta demostración en $coach_env."
        psql_env "$coach_env" < tests/coach-remove.sql || echo "Cuando PostgreSQL esté disponible, ejecuta make coach-remove ENV=$coach_env." >&2
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

web_prefix() {
    if [[ $1 == prod ]]; then echo "$prod-web"; else echo practica2-web; fi
}

# En dev, la base y las réplicas conservan los nombres de la primera práctica.
container_name() {
    local e=$1 service=$2
    if [[ $service == db && $e == dev ]]; then
        echo practica2-db
    elif [[ $service =~ ^web-[0-9]+$ ]]; then
        printf '%s-%s\n' "$(web_prefix "$e")" "${service#web-}"
    elif [[ $service =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
        echo "practica2-$e-$service"
    else
        echo "Indica un servicio con C=db, C=nginx o C=web-2. Usa make docker-ps para ver los del entorno." >&2
        return 2
    fi
}

docker_action() {
    local action=$1 e=$2 name
    if [[ $action == ps ]]; then
        local filters=(--filter "name=^/practica2-$e-")
        if [[ $e == dev ]]; then filters+=(--filter 'name=^/practica2-(db$|web-[0-9]+$)'); fi
        docker ps -a "${filters[@]}" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
        return
    fi
    name=$(container_name "$e" "${C:-}")
    if [[ $action == logs ]]; then
        docker logs --tail 30 "$name"
    else
        echo "docker $action $name"
        docker "$action" "$name"
    fi
}

# Leemos el puerto publicado por Docker para respetar el valor de terraform.tfvars.
url() {
    local binding
    binding=$(docker port "practica2-$1-$2" | awk 'NR==1 {print $3}')
    [[ -n $binding ]] || { echo "Falta el puerto de $1/$2. Comprueba make estado." >&2; return 1; }
    printf 'http://%s\n' "${binding/0.0.0.0/127.0.0.1}"
}
get() { curl --fail-early -fsS --max-time 8 "$1"; }

arquitectura() {
    echo "Cada entorno usa su main.tf, su terraform.tfvars y su propio estado."
    echo "Módulos desplegados según terraform state list:"
    for e in dev prod; do
        printf '%s: ' "$e"
        terraform -chdir="environments/$e" state list | awk -F. '$1=="module" {print $2}' | sort -u | paste -sd ' ' -
    done
}

estado() {
    docker ps -a --filter 'name=practica2-' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    for e in dev prod; do
        printf '\n%s · Web %s/jugadores · Dashboard %s/d/web-balanceador/web-y-balanceador\n' \
            "$e" "$(url "$e" nginx)" "$(url "$e" grafana)"
        get "$(url "$e" nginx)/health" | jq -e 'select(.status == "healthy")'
    done
}

redes() {
    for e in dev prod; do
        docker network inspect "practica2-$e-internal-network" "practica2-$e-public-network" \
            --format '{{.Name}} · interna={{.Internal}}'
        docker port "practica2-$e-nginx"
    done
}

replicas() {
    local e=$1 prefix base expected pages observed n minimum
    prefix=$(web_prefix "$e")
    base=$(url "$e" nginx)
    expected=$(docker ps --format '{{.Names}}' | grep -Ex "${prefix}-[0-9]+" | sort -u)
    n=$(wc -l <<< "$expected")
    minimum=2
    if [[ $e == prod ]]; then minimum=3; fi
    (( n >= ${2:-$minimum} )) || { echo "Solo hay $n réplicas activas en $e" >&2; return 1; }
    # curl reutiliza la conexión al balanceador. Cada página identifica su réplica en el HTML.
    pages=$(get "$base/jugadores?turno=[1-$((n * 4))]" | sed -n 's/.*Instancia web: <strong>\([^<]*\)<\/strong>.*/\1/p')
    printf '%s · %s/jugadores\n%s\n' "$e" "$base" "$pages"
    observed=$(sort -u <<< "$pages")
    [[ $observed == "$expected" ]] || { echo "La web no mostró todas las réplicas activas." >&2; return 1; }
}

psql_env() {
    local name
    name=$(container_name "$1" db)
    shift
    # Solo los scripts SQL leen stdin. Las consultas con -c dejan los Enter para la demo.
    local stdin=()
    if (( $# == 0 )); then stdin=(-i); fi
    docker exec "${stdin[@]}" "$name" sh -ec 'exec psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"' sh "$@"
}

db() {
    local name
    name=$(container_name "$1" db)
    psql_env "$1" -c "SELECT count(*) AS jugadores, count(*) FILTER (WHERE posicion = 'Entrenador') AS entrenadores FROM jugadores"
    docker inspect "$name" --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} → {{.Destination}}{{end}}{{end}}'
}

# Revisamos el plan antes de aplicarlo. La prueba solo sustituye el contenedor de la base.
recrear_db() (
    local e=$1 addr=module.postgres.docker_container.db work
    work=$(mktemp -d)
    trap 'rm -f -- "$work/db.plan"; rmdir -- "$work"' EXIT
    local tf=(terraform "-chdir=environments/$e")
    "${tf[@]}" plan -input=false -target="$addr" -replace="$addr" -out="$work/db.plan" >/dev/null
    if ! "${tf[@]}" show -json "$work/db.plan" | jq -e --arg addr "$addr" '
        [.resource_changes[] | select(.change.actions != ["no-op"] and .change.actions != ["read"])]
        | length == 1 and .[0].address == $addr
          and (.[0].change.actions | sort | . == ["create","delete"] or . == ["create"])
    ' >/dev/null; then
        echo "El plan incluye algo distinto de crear o sustituir el contenedor PostgreSQL. Revísalo con make plan ENV=$e." >&2
        return 1
    fi
    "${tf[@]}" apply -input=false "$work/db.plan"
)

coach_id() {
    psql_env "$1" -Atc "SELECT id FROM jugadores WHERE nombre = '$coach_name'"
}

coach_web() {
    local page i
    for i in {1..40}; do
        # En prod el listado de Redis puede tardar hasta 30 s en reflejar el cambio.
        if page=$(get "$1"); then
            if [[ $page == *"data-name=\"$coach_name\""* ]]; then
                if [[ $2 == presente ]]; then break; fi
            elif [[ $2 == ausente && $page == *'class="player-card"'* ]]; then
                break
            fi
        fi
        if (( i == 40 )); then echo "La web no muestra el estado esperado ($2)." >&2; return 1; fi
        sleep 1
    done
    echo "$1 · $coach_name: $2"
}

persistencia() {
    local e=$1 name page old_id new_id volume new_volume row before after
    name=$(container_name "$e" db)
    page="$(url "$e" nginx)/jugadores"
    local mount='{{range .Mounts}}{{if and (eq .Type "volume") (eq .Destination "/var/lib/postgresql/data")}}{{.Name}}{{end}}{{end}}'
    old_id=$(docker inspect -f '{{.Id}}' "$name")
    volume=$(docker inspect -f "$mount" "$name")
    [[ -n $volume ]] || { echo "PostgreSQL necesita su volumen de datos para esta prueba." >&2; return 1; }
    before=$(coach_id "$e")
    [[ -z $before ]] || { echo "$coach_name ya existe (id=$before). La prueba requiere que esté ausente al empezar." >&2; return 1; }
    echo "Antes del alta: entrenador ausente en SQL. Contenedor ${old_id:0:12} · volumen $volume"
    echo "make coach-add ENV=$e"
    psql_env "$e" < tests/coach-add.sql
    coach_env=$e
    row=$(coach_id "$e")
    [[ -n $row ]]
    coach_web "$page" presente
    pause "Abre $page y mira Cuerpo técnico. Enter para eliminar y recrear solo $name con Terraform."
    recrear_db "$e"
    new_id=$(docker inspect -f '{{.Id}}' "$name")
    new_volume=$(docker inspect -f "$mount" "$name")
    after=$(coach_id "$e")
    printf 'Contenedor %s → %s\nVolumen %s → %s\nEntrenador en SQL: id %s → %s\n' \
        "${old_id:0:12}" "${new_id:0:12}" "$volume" "$new_volume" "$row" "$after"
    [[ $old_id != "$new_id" && $volume == "$new_volume" && $row == "$after" ]] || { echo "Falló la comprobación de persistencia." >&2; return 1; }
    coach_web "$page" presente
    pause "El contenedor ha cambiado y el entrenador sigue en la web. Enter para ejecutar coach-remove."
    psql_env "$e" < tests/coach-remove.sql
    after=$(coach_id "$e")
    [[ -z $after ]] || { echo "El entrenador sigue en SQL." >&2; return 1; }
    coach_env=''
    echo "Baja confirmada en PostgreSQL."
    coach_web "$page" ausente
}

cache() {
    local base origen i
    base=$(url prod nginx)
    for i in 1 2 3; do
        origen=$(get "$base/jugadores" | sed -n 's/.*Origen del listado en esta carga: <strong>\([^<]*\)<\/strong>.*/\1/p')
        echo "Petición $i · origen del listado: $origen"
        if [[ $origen == Redis ]]; then return 0; fi
    done
    echo "Ninguna respuesta usó Redis." >&2; return 1
}

redis_estado_web() {
    local base=$1 esperado=$2 codigo=$3 respuesta i
    # La UI consulta /health cada 5 s. Flask devuelve 503 con JSON si pierde Redis.
    for i in {1..15}; do
        if respuesta=$(curl -sS --max-time 5 -w '\n%{http_code}' "$base/health") &&
           [[ ${respuesta##*$'\n'} == "$codigo" ]] &&
           jq -e --arg cache "$esperado" '.services.db == "connected" and .services.cache == $cache' \
               <<< "${respuesta%$'\n'*}" >/dev/null; then
            echo "/health → HTTP $codigo · PostgreSQL conectado · Redis $esperado"
            return
        fi
        sleep 1
    done
    echo "No se alcanzó el estado esperado de /health para Redis ($esperado)." >&2
    return 1
}

caida-redis() {
    local base page
    base=$(url prod nginx)
    redis_estado_web "$base" connected 200
    pause "Abre $base/jugadores y localiza el indicador de Redis. Enter para parar el contenedor."
    stopped=("$prod-redis")
    docker stop "${stopped[@]}"
    redis_estado_web "$base" disconnected 503
    page=$(get "$base/jugadores")
    [[ $page == *'Origen del listado en esta carga: <strong>PostgreSQL</strong>'* && $page == *'class="player-card"'* ]] || {
        echo "La página no mostró los jugadores obtenidos de PostgreSQL." >&2; return 1
    }
    echo "/jugadores sigue sirviendo la plantilla de jugadores desde PostgreSQL."
    pause "Observa «Sin conexión», recarga la página y enseña el origen PostgreSQL. Enter para arrancar Redis."
    restore
    redis_estado_web "$base" connected 200
    cache
    pause "Comprueba que el indicador vuelve a «Conectado». Enter para continuar."
}

minio() {
    local path=static/images/jugadores/david-raya.avif base nginx conf endpoint bucket object page
    base=$(url "$1" nginx)
    nginx=$(container_name "$1" nginx)
    page=$(get "$base/jugadores")
    [[ $page == *"src=\"/$path\""* ]] || { echo "Falta la referencia a la foto de David Raya en la página." >&2; return 1; }
    echo "1. Flask entrega el HTML de /jugadores. La ficha de David Raya contiene src=\"/$path\"."
    conf=$(docker exec "$nginx" cat /etc/nginx/conf.d/default.conf)
    endpoint=$(awk '/^upstream imagenes_minio /{inside=1} inside && $1=="server"{print $2; exit}' <<< "$conf")
    bucket=$(sed -n 's@^[[:space:]]*proxy_pass http://imagenes_minio/\([^/]*\)/;@\1@p' <<< "$conf")
    [[ -n $endpoint && -n $bucket ]] || { echo "Revisa la ruta de imágenes en la configuración activa de Nginx." >&2; return 1; }
    object="http://$endpoint/$bucket/${path#static/images/}"
    echo "2. El navegador pide la foto en $base/$path. La configuración de Nginx dirige esa ruta a $object."
    docker exec "$nginx" wget -qO- "$object" | cmp - "app/$path"
    get "$base/$path" | cmp - "app/$path"
    echo "3. Coinciden los bytes del objeto en MinIO, la respuesta pública de Nginx y la foto original."
}

# Grafana consulta sus fuentes internas con las mismas rutas que usa el dashboard.
grafana() {
    local e=$1 route=$2
    shift 2
    docker exec "practica2-$e-grafana" sh -c \
        'url="http://localhost:3000$1"; shift; exec curl -fsS --max-time 8 -u "admin:$GF_SECURITY_ADMIN_PASSWORD" "$url" "$@"' \
        sh "$route" "$@"
}

metricas() {
    local base prefix metric
    base=$(url "$1" nginx)
    prefix=$(web_prefix "$1")
    echo "Generando 60 visitas a /jugadores para el gráfico de tráfico."
    get "$base/jugadores?demo=[1-60]" >/dev/null
    for metric in docker_container_cpu_usage_percent docker_container_mem_usage; do
        echo "$metric"
        grafana "$1" /api/datasources/proxy/uid/prometheus/api/v1/query -G \
            --data-urlencode "query=max by (container_name) (${metric}{job=\"containers\",container_name=~\"${prefix}-[0-9]+\"})" |
            jq -er '.data.result | select(length > 0) | .[] | [.metric.container_name,.value[1]] | @tsv'
    done
    echo "Dashboard de CPU (%), memoria y tráfico: $(url "$1" grafana)/d/web-balanceador/web-y-balanceador"
}

logs() {
    local e=$1 marker="defensa-$(date +%s)-$$" base query lines i
    base=$(url "$e" nginx)
    echo "1. Hacemos una visita con una marca única para reconocerla entre las demás."
    curl -fsS --max-time 8 -o /dev/null -w 'GET %{url_effective} → HTTP %{http_code}\n' "$base/jugadores?demo=$marker"
    query="{container=\"practica2-$e-nginx\"} |= \"$marker\""
    echo "2. Desde Grafana consultamos Loki. Filtramos por el contenedor Nginx y buscamos esa marca: $query"
    for i in {1..15}; do
        lines=$(grafana "$e" /api/datasources/proxy/uid/loki/loki/api/v1/query_range -G \
            --data-urlencode "query=$query" | jq -r '.data.result[].values[][1]')
        if [[ -n $lines ]]; then
            echo "$lines"
            echo "3. El GET, la marca y el código HTTP identifican la visita. Alloy ha recogido el acceso de Nginx y ya se puede leer en Loki."
            echo "$(url "$e" grafana)/d/web-balanceador/web-y-balanceador?var-contenedor=practica2-$e-nginx"
            return
        fi
        sleep 1
    done
    echo "Loki todavía no ha devuelto la petición $marker." >&2; return 1
}

wait_web() {
    local base i
    base=$(url prod nginx)
    for i in {1..30}; do
        if get "$base/health" >/dev/null 2>&1; then return; fi
        sleep 1
    done
    echo "El balanceador no responde tras 30 segundos." >&2; return 1
}

failover() {
    replicas prod
    [[ $(docker inspect --format '{{.State.Running}}' "$prod-web-2") == true ]] || { echo "web-2 debe estar activa al inicio."; return 1; }
    pause "Enter para parar web-2 y enseñar que las otras siguen atendiendo."
    stopped=("$prod-web-2")
    docker stop "${stopped[@]}"
    wait_web
    replicas prod 2
    pause "Muestra en Grafana las réplicas activas. Enter para restaurar web-2."
    restore
    sleep 6  # El resolver de Nginx conserva la respuesta DNS durante 5 segundos.
    replicas prod
}

alert_state() {
    grafana prod /api/prometheus/grafana/api/v1/rules |
        jq -er '.data.groups[].rules[] | select(.name == "Producción sin réplicas Flask en ejecución") | .state'
}

alerta() {
    local names state previous='' deadline
    echo "Abre $(url prod grafana)/alerting/grafana/prod-web-sin-replicas/view"
    replicas prod
    [[ $(alert_state) == inactive ]] || { echo "La regla debe empezar en Normal."; return 1; }
    names=$(docker ps --format '{{.Names}}' | grep -Ex 'practica2-prod-web-[0-9]+')
    pause "Enter para parar todas las réplicas de prod y activar la regla real de correo."
    mapfile -t stopped <<< "$names"
    docker stop "${stopped[@]}"
    deadline=$((SECONDS + 180))
    while (( SECONDS < deadline )); do
        state=$(alert_state)
        if [[ $state != "$previous" ]]; then echo "Grafana: $state"; previous=$state; fi
        if [[ $state == firing ]]; then break; fi
        sleep 3
    done
    [[ $state == firing ]] || { echo "La regla no llegó a Firing en 3 minutos."; return 1; }
    pause "Muestra Firing y el correo recibido. Enter para recuperar producción."
    restore
    wait_web
    for _ in {1..30}; do
        if [[ $(alert_state) == inactive ]]; then
            echo "Grafana vuelve a Normal. El correo RESOLVED puede tardar varios minutos."
            return
        fi
        sleep 2
    done
    echo "La web responde, pero la regla sigue pendiente de recuperación."; return 1
}

check() {
    estado
    replicas dev
    replicas prod
}

paso() {
    printf '\n── %s ──\n%s\n' "$1" "$2"
    shift 2
    printf '  make %s' "$1"
    if [[ -n ${2:-} ]]; then printf ' ENV=%s' "$2"; fi
    printf '\n'
    pause "Enter para demostrarlo."
    "$@"
}

case ${1:-demo} in
    demo)
        echo "Defensa de Terraform · Selección española · Enter avanza, q sale."
        echo "Los dos entornos deben estar desplegados (make up-all)."
        paso "Arquitectura · Terraform" "Enseña los módulos comunes y la caché específica de prod. Los valores de cada entorno están en su terraform.tfvars." arquitectura
        paso "1 · Despliegue simultáneo" "Environments separa los estados y cada main reutiliza los módulos. Abre ambas webs." estado
        paso "2 · Redes Docker" "Nginx conecta la red pública con los servicios internos." redes
        paso "3 · Desarrollo" "En /jugadores se ve el hostname de cada una de las dos instancias." replicas dev
        paso "4 · Producción" "Round robin reparte el turno entre réplicas equivalentes con el mismo peso." replicas prod
        paso "5 · PostgreSQL" "Consulta real al catálogo y volumen donde persisten sus datos." db prod
        paso "6 · Redis" "Flask guarda el listado 30 s en prod. La página indica su origen." cache
        paso "7 · Almacenamiento compartido" "La página y la foto viajan en dos peticiones. Sigue la foto de David Raya desde el HTML hasta el objeto de MinIO." minio prod
        paso "8 · Métricas" "Telegraf mide Docker, Prometheus recoge los valores y Grafana los dibuja." metricas prod
        paso "9 · Logs centralizados" "Hacemos una visita identificable a /jugadores y enseñamos esa misma visita en el registro centralizado." logs prod
        paso "10 · Alta disponibilidad" "Con una réplica caída seguimos viendo la web." failover
        paso "11 · Alerta y recuperación" "Con cero réplicas durante 30 s Grafana activa el aviso." alerta
        ;;
    check|arquitectura|estado|redes|cache|caida-redis|failover|alerta) "$1" ;;
    coach-add|coach-remove) psql_env "$env" < "tests/$1.sql" ;;
    recrear-db) pause "Enter para recrear PostgreSQL en $env con su volumen existente."; recrear_db "$env" ;;
    docker-ps|docker-stop|docker-start|docker-restart|docker-rm|docker-logs) docker_action "${1#docker-}" "$env" ;;
    replicas|db|persistencia|minio|metricas|logs) "$1" "$env" ;;
    *) echo "Consulta make help para ver las pruebas disponibles." >&2; exit 2 ;;
esac
