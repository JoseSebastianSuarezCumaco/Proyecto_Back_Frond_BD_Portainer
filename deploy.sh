#!/bin/bash

set -e

echo "=========================================="
echo "   DESPLIEGUE LISTA DE TAREAS"
echo "=========================================="

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo
echo "[1/10] Comprobando Docker..."

if ! command -v docker >/dev/null 2>&1; then
    echo "Docker no está instalado."
    exit 1
fi

echo "Docker OK"

echo
echo "[2/10] Comprobando Docker Compose..."

if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE="docker compose"
else
    echo "Docker Compose no está instalado."
    exit 1
fi

echo "Compose OK"

echo
echo "[3/10] Comprobando archivos del proyecto..."

if [ ! -f "docker-compose.yml" ]; then
    echo "No existe docker-compose.yml"
    exit 1
fi

if [ ! -f "backend/Dockerfile" ]; then
    echo "No existe backend/Dockerfile"
    exit 1
fi

if [ ! -f "frontend/Dockerfile" ]; then
    echo "No existe frontend/Dockerfile"
    exit 1
fi

echo "Archivos OK"

echo
echo "[4/10] Comprobando conexión del frontend con el backend..."

if grep -q "private apiUrl = '/api/tasks'" frontend/src/app/services/task.service.ts; then
    echo "apiUrl ya está configurado correctamente."
else
    echo "Corrigiendo apiUrl del frontend..."
    sed -i "s#private apiUrl.*#private apiUrl = '/api/tasks';#" frontend/src/app/services/task.service.ts
    echo "apiUrl corregido."
fi

echo
echo "[5/10] Configurando Nginx..."

cat > frontend/nginx.conf <<'NGINX'
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
NGINX

echo "Nginx configurado."

echo
echo "[6/10] Comprobando Java y Maven..."

if ! command -v java >/dev/null 2>&1; then
    echo "Java no está instalado."
    echo "Instalando OpenJDK 17..."
    apt-get update -y
    apt-get install -y openjdk-17-jdk
fi

if ! command -v mvn >/dev/null 2>&1; then
    echo "Maven no está instalado."
    echo "Instalando Maven..."
    apt-get update -y
    apt-get install -y maven
fi

echo "Java:"
java -version

echo
echo "Maven:"
mvn -version

echo
echo "[7/10] Comprobando el archivo JAR del backend..."

if [ -f "backend/target/backend-0.0.1.jar" ]; then
    echo "JAR encontrado:"
    ls -lh backend/target/backend-0.0.1.jar
else
    echo "JAR no encontrado."
    echo "Compilando backend con Maven..."

    cd backend

    mvn clean package -DskipTests

    cd "$PROJECT_DIR"

    if [ ! -f "backend/target/backend-0.0.1.jar" ]; then
        echo
        echo "ERROR: Maven terminó pero no se encontró:"
        echo "backend/target/backend-0.0.1.jar"
        echo
        echo "Archivos generados:"
        find backend/target -maxdepth 1 -type f -ls 2>/dev/null || true
        exit 1
    fi

    echo "JAR generado correctamente:"
    ls -lh backend/target/backend-0.0.1.jar
fi

echo
echo "[8/10] Configurando variables de entorno..."

if [ ! -f ".env" ]; then

    echo
    echo "No existe archivo .env."
    echo "Vamos a crear uno."
    echo

    read -p "MYSQL_ROOT_PASSWORD: " MYSQL_ROOT_PASSWORD

    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        echo "La contraseña de MySQL no puede quedar vacía."
        exit 1
    fi

    cat > .env <<ENV
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
SPRING_DATASOURCE_PASSWORD=$MYSQL_ROOT_PASSWORD
ENV

    echo ".env creado."
else
    echo ".env ya existe."
fi

echo
echo "[9/10] Construyendo y levantando los contenedores..."

$COMPOSE down --remove-orphans 2>/dev/null || true

$COMPOSE build

$COMPOSE up -d

echo
echo "Contenedores:"
$COMPOSE ps

echo
echo "Esperando al backend..."

BACKEND_OK=0

for i in $(seq 1 30); do

    if curl -s http://127.0.0.1:8080/api/tasks >/dev/null 2>&1; then
        BACKEND_OK=1
        break
    fi

    echo "Esperando... ($i/30)"
    sleep 2
done

if [ "$BACKEND_OK" -eq 1 ]; then
    echo
    echo "BACKEND OK"
    echo
    echo "Respuesta:"
    curl -s http://127.0.0.1:8080/api/tasks
    echo
else
    echo
    echo "ERROR: El backend no respondió."
    echo
    echo "Logs del backend:"
    $COMPOSE logs --tail=80 backend
    exit 1
fi

echo
echo "[10/10] Comprobando frontend y proxy Nginx..."

echo
echo "Frontend:"
curl -I http://127.0.0.1:80

echo
echo "API mediante Nginx:"
curl -s http://127.0.0.1:80/api/tasks

echo

echo "=========================================="
echo "       DESPLIEGUE COMPLETADO"
echo "=========================================="

echo
echo "Frontend:"
echo "http://localhost"

echo
echo "Backend directo:"
echo "http://localhost:8080/api/tasks"

echo
echo "API mediante Nginx:"
echo "http://localhost/api/tasks"

echo
echo "Contenedores:"
$COMPOSE ps

echo
echo "=========================================="
echo " Ahora puedes configurar ngrok sobre"
echo " el puerto 80."
echo "=========================================="
