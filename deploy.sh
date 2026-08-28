#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=========================================="
echo "   DESPLIEGUE LISTA DE TAREAS"
echo "=========================================="
echo

cd "$PROJECT_DIR"

echo "[1/9] Comprobando Docker..."

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker no está instalado. Instalando..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
fi

echo "Docker OK"
echo

echo "[2/9] Comprobando Docker Compose..."

if docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE="docker-compose"
else
    echo "Instalando Docker Compose..."
    apt-get update
    apt-get install -y docker-compose
    COMPOSE="docker-compose"
fi

echo "Compose OK"
echo

echo "[3/9] Comprobando archivos del proyecto..."

if [ ! -f "docker-compose.yml" ]; then
    echo "ERROR: no existe docker-compose.yml"
    exit 1
fi

if [ ! -f "frontend/Dockerfile" ]; then
    echo "ERROR: no existe frontend/Dockerfile"
    exit 1
fi

if [ ! -f "frontend/nginx.conf" ]; then
    echo "ERROR: no existe frontend/nginx.conf"
    exit 1
fi

echo "Archivos OK"
echo

echo "[4/9] Comprobando conexión del frontend con el backend..."

if [ -f "frontend/src/app/services/task.service.ts" ]; then

    if grep -q "private apiUrl = 'http://10." \
        frontend/src/app/services/task.service.ts 2>/dev/null; then

        echo "Se encontró una IP fija en apiUrl."
        echo "Cambiándola a /api/tasks..."

        sed -i -E \
        "s#private apiUrl = .*#private apiUrl = '/api/tasks';#" \
        frontend/src/app/services/task.service.ts

    elif grep -q "private apiUrl = '/api/tasks'" \
        frontend/src/app/services/task.service.ts; then

        echo "apiUrl ya está configurado correctamente."

    else
        echo "No se pudo comprobar automáticamente apiUrl."
        echo "Revisa frontend/src/app/services/task.service.ts"
    fi
fi

echo

echo "[5/9] Configurando Nginx..."

cat > frontend/nginx.conf <<'EOF'
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://backend:8080/api/;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

echo "Nginx configurado."
echo

echo "[6/9] Comprobando Docker Compose..."

echo
echo "Contenedores actuales:"
$COMPOSE ps || true
echo

echo "[7/9] Construyendo las imágenes..."

$COMPOSE down --remove-orphans 2>/dev/null || true

$COMPOSE build

echo

echo "[8/9] Levantando la aplicación..."

$COMPOSE up -d

echo
echo "Esperando unos segundos..."
sleep 10

echo

echo "=========================================="
echo "      ESTADO DE LOS CONTENEDORES"
echo "=========================================="

docker ps

echo

echo "[9/9] Probando backend..."

BACKEND_OK=0

for i in {1..20}; do

    if curl -sf http://127.0.0.1:8080/api/tasks >/tmp/tasks_response.txt 2>/dev/null; then
        BACKEND_OK=1
        break
    fi

    sleep 2
done

if [ "$BACKEND_OK" -eq 1 ]; then
    echo "BACKEND OK"
    echo
    echo "Respuesta:"
    cat /tmp/tasks_response.txt
else
    echo "ERROR: el backend no responde."
    echo
    echo "Últimos logs del backend:"
    $COMPOSE logs --tail=50 backend
    exit 1
fi

echo
echo "=========================================="
echo "       PROBANDO NGINX / FRONTEND"
echo "=========================================="

if curl -sf http://127.0.0.1/api/tasks >/tmp/proxy_response.txt 2>/dev/null; then

    echo "NGINX + BACKEND OK"
    echo
    echo "Respuesta mediante proxy:"
    cat /tmp/proxy_response.txt

else

    echo "ERROR: Nginx no puede comunicarse con el backend."
    echo
    echo "Configuración de Nginx:"
    cat frontend/nginx.conf
    echo
    echo "Logs del frontend:"
    $COMPOSE logs --tail=50 frontend
    exit 1

fi

echo
echo "=========================================="
echo "       INSTALANDO / COMPROBANDO NGROK"
echo "=========================================="

if ! command -v ngrok >/dev/null 2>&1; then

    echo "ngrok no está instalado."

    echo "Instalando ngrok..."

    curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
        | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null

    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" \
        | tee /etc/apt/sources.list.d/ngrok.list >/dev/null

    apt-get update
    apt-get install -y ngrok

fi

echo
echo "ngrok OK"
echo

echo "=========================================="
echo "          CONFIGURACIÓN DE NGROK"
echo "=========================================="
echo

read -s -p "Introduce tu Authtoken de ngrok: " NGROK_TOKEN
echo
echo

if [ -z "$NGROK_TOKEN" ]; then
    echo "No se introdujo token."
    echo "La aplicación queda funcionando localmente."
    echo
    echo "Frontend: http://localhost"
    echo "Backend:  http://localhost:8080/api/tasks"
    exit 0
fi

ngrok config add-authtoken "$NGROK_TOKEN"

echo
echo "Iniciando ngrok..."
echo

pkill -f "ngrok http" 2>/dev/null || true
sleep 2

nohup ngrok http 80 > /tmp/ngrok.log 2>&1 &

sleep 5

echo
echo "=========================================="
echo "          RESULTADO FINAL"
echo "=========================================="
echo

echo "Frontend:"
echo "http://localhost"

echo
echo "Backend:"
echo "http://localhost:8080/api/tasks"

echo
echo "Proxy Nginx:"
echo "http://localhost/api/tasks"

echo

PUBLIC_URL=""

for i in {1..15}; do

    PUBLIC_URL=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null \
        | grep -oE '"public_url":"[^"]+"' \
        | head -n1 \
        | cut -d'"' -f4)

    if [ -n "$PUBLIC_URL" ]; then
        break
    fi

    sleep 1
done

if [ -n "$PUBLIC_URL" ]; then

    echo "=========================================="
    echo "          URL PUBLICA NGROK"
    echo "=========================================="
    echo
    echo "$PUBLIC_URL"
    echo
    echo "Abre esa URL en el navegador."
    echo

else

    echo "No se pudo obtener automáticamente la URL."
    echo
    echo "Revisa:"
    echo "cat /tmp/ngrok.log"
    echo

fi

echo "=========================================="
echo "           DESPLIEGUE TERMINADO"
echo "=========================================="
echo
echo "Contenedores:"
docker ps
echo
echo "Para ver logs:"
echo "$COMPOSE logs -f"
echo
echo "Para detener todo:"
echo "$COMPOSE down"
echo
echo "Para detener ngrok:"
echo "pkill -f 'ngrok http'"
echo
