# Bot de Respaldo Nextcloud a Telegram

[![GitHub](https://img.shields.io/badge/GitHub-FranderProg-blue)](https://github.com/FranderProg/nextcloud-telegram-backup)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue)](https://github.com/FranderProg/nextcloud-telegram-backup)
[![CasaOS](https://img.shields.io/badge/CasaOS-Compatible-green)](https://github.com/FranderProg/nextcloud-telegram-backup)

Sistema automático de respaldo que monitorea archivos nuevos en Nextcloud y los envía automáticamente a un grupo de Telegram con hashtags para facilitar la búsqueda.

**Repositorio**: [https://github.com/FranderProg/nextcloud-telegram-backup](https://github.com/FranderProg/nextcloud-telegram-backup)

## 🚀 Características

- **Monitoreo automático**: Detecta archivos nuevos en Nextcloud usando `watchdog`
- **Envío a Telegram**: Envía archivos como documentos para mantener la calidad original
- **Hashtags automáticos**: Genera hashtags basados en el tipo y nombre del archivo
- **Interfaz web**: Panel de control para monitorear el progreso y estado
- **Soporte múltiples formatos**: Imágenes, videos, documentos y audio
- **Sistema de colas**: Procesa archivos de forma ordenada con reintentos
- **Dockerizado**: Fácil instalación en CasaOS

## 📋 Requisitos

- CasaOS con Docker
- Nextcloud instalado
- Bot de Telegram creado
- Acceso al directorio de datos de Nextcloud

## 🛠️ Instalación en CasaOS

### 1. Preparar el Bot de Telegram

1. Crea un bot con [@BotFather](https://t.me/botfather)
2. Obtén el token del bot
3. Agrega el bot a tu grupo de Telegram
4. Obtén el ID del chat del grupo

### 2. Configurar el Sistema

1. **Clona o descarga este proyecto** en tu servidor CasaOS
2. **Edita el archivo `docker-compose.yml`**:
   ```yaml
   volumes:
     - /ruta/a/tu/nextcloud/data:/nextcloud/data:ro
   ```
   Reemplaza `/ruta/a/tu/nextcloud/data` con la ruta real de tu Nextcloud

3. **Configura las variables de entorno**:
   - `TELEGRAM_BOT_TOKEN`: Token de tu bot
   - `TELEGRAM_CHAT_ID`: ID del chat/grupo
   - `NEXTCLOUD_PATH`: Ruta dentro del contenedor (no cambiar)

### 3. Instalación desde CasaOS

#### Opción A: Instalación Manual
1. En CasaOS, ve a **Apps** → **Custom App**
2. Copia el contenido del `docker-compose.yml`
3. Configura las variables de entorno
4. Ajusta las rutas de volúmenes
5. Despliega la aplicación

#### Opción B: Instalación desde Terminal
```bash
# Navegar al directorio del proyecto
cd /ruta/al/proyecto

# Editar docker-compose.yml con tus rutas
nano docker-compose.yml

# Iniciar los servicios
docker-compose up -d
```

### 4. Verificar Instalación

1. **Interfaz Web**: Accede a `http://tu-servidor:8081`
2. **Logs**: Verifica los logs con `docker-compose logs -f`
3. **Telegram**: Envía un archivo a Nextcloud para probar

## 🔧 Configuración Avanzada

### Variables de Entorno

| Variable | Descripción | Valor por Defecto |
|----------|-------------|-------------------|
| `TELEGRAM_BOT_TOKEN` | Token del bot de Telegram | Requerido |
| `TELEGRAM_CHAT_ID` | ID del chat/grupo | Requerido |
| `NEXTCLOUD_PATH` | Ruta del directorio de Nextcloud | `/nextcloud/data` |
| `LOG_LEVEL` | Nivel de logging | `INFO` |

### Formatos Soportados

- **Imágenes**: jpg, jpeg, png, gif, bmp, tiff, webp, svg
- **Videos**: mp4, avi, mov, wmv, flv, webm, mkv, m4v
- **Documentos**: pdf, doc, docx, txt, rtf
- **Audio**: mp3, wav, flac, aac, ogg

### Hashtags Generados

El sistema genera automáticamente hashtags como:
- `#imagen`, `#video`, `#documento`, `#audio`
- `#jpg`, `#mp4`, `#pdf` (extensión del archivo)
- `#nombre_archivo` (nombre sin espacios)
- `#foto`, `#grabacion` (según el tipo)

## 📊 Interfaz Web

La interfaz web (`http://tu-servidor:8081`) incluye:

- **Dashboard**: Estadísticas en tiempo real
- **Cola de Procesamiento**: Archivos pendientes de envío
- **Historial**: Archivos ya procesados
- **Controles**: Limpiar cola e historial
- **Paginación**: Navegación por archivos procesados

## 🔍 Solución de Problemas

### El bot no envía archivos
1. Verifica que el token del bot sea correcto
2. Asegúrate de que el bot esté en el grupo
3. Revisa los logs: `docker-compose logs backup_bot`

### No se detectan archivos nuevos
1. Verifica la ruta de Nextcloud en `docker-compose.yml`
2. Asegúrate de que el directorio sea accesible
3. Revisa los permisos del directorio

### Error de conexión a Redis
1. Verifica que el contenedor Redis esté ejecutándose
2. Revisa la configuración de red en Docker

### Archivos muy grandes
- Telegram tiene un límite de 50MB por archivo
- Los archivos más grandes se omiten automáticamente

## 📝 Logs

Los logs se almacenan en:
- **Contenedor**: `/app/logs/backup_bot.log`
- **Host**: `./logs/backup_bot.log`

Para ver logs en tiempo real:
```bash
docker-compose logs -f nextcloud-backup-bot
```

## 🔄 Actualización

Para actualizar el sistema:
```bash
# Detener servicios
docker-compose down

# Actualizar código
git pull  # o descargar nueva versión

# Reconstruir y reiniciar
docker-compose up -d --build
```

## 🛡️ Seguridad

- El directorio de Nextcloud se monta como **solo lectura**
- Los tokens se pasan como variables de entorno
- Redis no expone puertos externos
- La interfaz web es solo para monitoreo

## 📞 Soporte

Si encuentras problemas:
1. Revisa los logs del sistema
2. Verifica la configuración de Docker
3. Asegúrate de que Nextcloud esté funcionando correctamente
4. Verifica la conectividad a Telegram

## 🎯 Próximas Características

- [ ] Filtros por tipo de archivo
- [ ] Programación de respaldos
- [ ] Notificaciones de estado
- [ ] Compresión de archivos grandes
- [ ] Múltiples grupos de destino
