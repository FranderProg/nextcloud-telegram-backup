# 🚀 Guía de Instalación Rápida - Bot de Respaldo Nextcloud a Telegram

## 📋 Resumen del Sistema

Este sistema monitorea automáticamente tu Nextcloud y envía todos los archivos nuevos a un grupo de Telegram con hashtags para facilitar la búsqueda. Incluye una interfaz web para monitorear el progreso.

## ⚡ Instalación Rápida (Ubuntu/CasaOS)

### 1. Descargar e Instalar

```bash
# Descargar el script de instalación
wget https://raw.githubusercontent.com/FranderProg/nextcloud-telegram-backup/main/install.sh

# Hacer ejecutable
chmod +x install.sh

# Ejecutar instalación
sudo ./install.sh
```

### 2. Configuración Durante la Instalación

El script te pedirá:
- **Token del Bot**: `8397420823:AAHktLrj-Urqi4TpepZRtYcFqSN5p2QMp7o`
- **ID del Chat**: `5642423602`
- **Ruta de Nextcloud**: Ejemplo `/var/lib/docker/volumes/nextcloud_data/_data`

### 3. Acceso a la Interfaz

Una vez instalado, accede a:
- **Interfaz Web**: `http://tu-servidor:8081`
- **Logs**: `sudo docker-compose logs -f`

## 🐳 Instalación Manual con Docker Compose

### 1. Preparar Archivos

```bash
# Crear directorio
mkdir nextcloud-telegram-backup
cd nextcloud-telegram-backup

# Descargar archivos del proyecto
# (Copia todos los archivos del proyecto aquí)
```

### 2. Configurar Variables

Edita el archivo `docker-compose.yml`:

```yaml
volumes:
  - /ruta/a/tu/nextcloud/data:/nextcloud/data:ro
```

### 3. Crear Archivo .env

```bash
cat > .env << EOF
TELEGRAM_BOT_TOKEN=8397420823:AAHktLrj-Urqi4TpepZRtYcFqSN5p2QMp7o
TELEGRAM_CHAT_ID=5642423602
NEXTCLOUD_DATA_PATH=/ruta/a/tu/nextcloud/data
LOG_LEVEL=INFO
REDIS_URL=redis://redis:6379
EOF
```

### 4. Ejecutar

```bash
# Construir e iniciar
docker-compose up -d --build

# Verificar estado
docker-compose ps

# Ver logs
docker-compose logs -f
```

## 🏠 Instalación en CasaOS

### Opción 1: App Store (Recomendado)

1. Ve a **Apps** en CasaOS
2. Busca "Nextcloud Telegram Backup"
3. Instala y configura las variables

### Opción 2: Custom App

1. Ve a **Apps** → **Custom App**
2. Copia el contenido de `casaos-app.json`
3. Configura las variables de entorno
4. Ajusta las rutas de volúmenes
5. Despliega

### Opción 3: Terminal

```bash
# En CasaOS, ejecuta el script de instalación
sudo ./install.sh
```

## 🔧 Configuración del Bot de Telegram

### 1. Crear Bot

1. Abre Telegram y busca `@BotFather`
2. Envía `/newbot`
3. Sigue las instrucciones
4. Guarda el token

### 2. Obtener ID del Chat

```bash
# Envía un mensaje al bot
# Luego ejecuta:
curl -s "https://api.telegram.org/botTU_TOKEN/getUpdates"
```

### 3. Agregar Bot al Grupo

1. Crea un grupo en Telegram
2. Agrega tu bot al grupo
3. Haz al bot administrador
4. Obtén el ID del grupo

## 📁 Rutas Comunes de Nextcloud

### Docker
```bash
/var/lib/docker/volumes/nextcloud_data/_data
/var/lib/docker/volumes/nextcloud_nextcloud/_data
```

### CasaOS
```bash
/var/lib/casaos/apps/nextcloud/data
```

### Instalación Manual
```bash
/var/www/nextcloud/data
/opt/nextcloud/data
```

## 🔍 Verificación de la Instalación

### 1. Verificar Servicios

```bash
docker-compose ps
```

Deberías ver:
- `nextcloud-telegram-backup` (Running)
- `nextcloud-backup-redis` (Running)
- `nextcloud-backup-web` (Running)

### 2. Verificar Logs

```bash
docker-compose logs nextcloud-backup-bot
```

Busca: `"Iniciando bot de respaldo de Nextcloud a Telegram"`

### 3. Probar Funcionamiento

1. Sube un archivo a Nextcloud
2. Verifica en la interfaz web (`:8081`)
3. Revisa que llegue a Telegram

## 🛠️ Comandos Útiles

### Gestión de Servicios

```bash
# Iniciar
docker-compose up -d

# Detener
docker-compose down

# Reiniciar
docker-compose restart

# Ver logs
docker-compose logs -f

# Reconstruir
docker-compose up -d --build
```

### Limpieza

```bash
# Limpiar logs
sudo rm -rf logs/*

# Limpiar datos de Redis
docker-compose down
docker volume rm nextcloud-telegram-backup_redis_data
docker-compose up -d
```

### Actualización

```bash
# Detener servicios
docker-compose down

# Actualizar código
git pull  # o descargar nueva versión

# Reconstruir
docker-compose up -d --build
```

## 🚨 Solución de Problemas

### El bot no envía archivos

1. **Verificar token**:
   ```bash
   curl -s "https://api.telegram.org/botTU_TOKEN/getMe"
   ```

2. **Verificar chat ID**:
   ```bash
   curl -s "https://api.telegram.org/botTU_TOKEN/getUpdates"
   ```

3. **Revisar logs**:
   ```bash
   docker-compose logs nextcloud-backup-bot
   ```

### No se detectan archivos

1. **Verificar ruta**:
   ```bash
   ls -la /ruta/a/nextcloud/data
   ```

2. **Verificar permisos**:
   ```bash
   docker-compose exec nextcloud-backup-bot ls -la /nextcloud/data
   ```

### Error de Redis

1. **Verificar Redis**:
   ```bash
   docker-compose logs redis
   ```

2. **Reiniciar Redis**:
   ```bash
   docker-compose restart redis
   ```

### Interfaz web no carga

1. **Verificar puerto**:
   ```bash
   netstat -tlnp | grep 8081
   ```

2. **Verificar logs**:
   ```bash
   docker-compose logs web-interface
   ```

## 📊 Monitoreo

### Interfaz Web
- **URL**: `http://tu-servidor:8081`
- **Funciones**: Ver cola, historial, estadísticas

### Logs
- **Ubicación**: `./logs/backup_bot.log`
- **Comando**: `docker-compose logs -f`

### Métricas
- Archivos en cola
- Archivos procesados
- Estado del sistema
- Tiempo de procesamiento

## 🔐 Seguridad

- ✅ Directorio de Nextcloud montado como solo lectura
- ✅ Tokens en variables de entorno
- ✅ Redis no expuesto externamente
- ✅ Interfaz web solo para monitoreo

## 📞 Soporte

Si tienes problemas:

1. Revisa los logs del sistema
2. Verifica la configuración de Docker
3. Asegúrate de que Nextcloud esté funcionando
4. Verifica la conectividad a Telegram

## 🎯 Características

- ✅ Monitoreo automático de archivos
- ✅ Envío a Telegram con hashtags
- ✅ Interfaz web de monitoreo
- ✅ Sistema de colas con reintentos
- ✅ Soporte múltiples formatos
- ✅ Dockerizado para CasaOS
- ✅ Logs detallados
- ✅ Configuración flexible

¡Disfruta de tu bot de respaldo automático! 🚀
