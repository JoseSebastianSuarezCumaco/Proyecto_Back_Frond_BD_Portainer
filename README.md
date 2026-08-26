# Proyecto Docker - Lista de Tareas

Aplicación de práctica de tres capas para el taller de Docker:

- **frontend/**: aplicación Angular (consumirá la API REST del backend).
- **backend/**: API REST en Java + Spring Boot.
- **database/**: scripts de inicialización de MySQL (carpeta `init/`).

## Estado actual

Etapa 1: solo estructura inicial de carpetas y archivos base.
Aún no hay Dockerfiles, docker-compose configurado, ni conexión real
entre las capas. Eso se irá agregando paso a paso.

## Próximos pasos

1. Confirmar que la estructura es correcta.
2. Completar la lógica del backend (Controller, Service, Repository).
3. Completar el frontend (consumo de la API con TaskService).
4. Escribir el script real de MySQL (`database/init/01-init.sql`).
5. Crear los Dockerfiles de frontend y backend.
6. Configurar `docker-compose.yml` (servicios, red, volumen).
