#!/bin/bash

# Script de instalación para CasaOS
# Bot de Respaldo Nextcloud a Telegram

set -e

echo "🤖 Instalador del Bot de Respaldo Nextcloud a Telegram"
echo "=================================================="

# Verificar que Docker esté instalado
if ! command -v docker &> /dev/null; then
    echo "❌ Docker no está instalado. Por favor instala Docker primero."
    exit 1
fi

# Verificar que Docker Compose esté instalado
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose no está instalado. Por favor instala Docker Compose primero."
    exit 1
fi

echo "✅ Docker y Docker Compose están instalados"

# Crear directorio del proyecto
PROJECT_DIR="/opt/nextcloud-telegram-backup"
echo "📁 Creando directorio del proyecto: $PROJECT_DIR"

sudo mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# Descargar archivos del proyecto
echo "📥 Descargando archivos del proyecto..."
echo "📁 Repositorio: https://github.com/FranderProg/nextcloud-telegram-backup"

# Crear docker-compose.yml
sudo tee docker-compose.yml > /dev/null << 'EOF'
version: '3.8'

services:
  nextcloud-backup-bot:
    build: .
    container_name: nextcloud-telegram-backup
    restart: unless-stopped
    environment:
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
      - TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
      - NEXTCLOUD_PATH=/nextcloud/data
      - LOG_LEVEL=INFO
    volumes:
      - ${NEXTCLOUD_DATA_PATH}:/nextcloud/data:ro
      - ./logs:/app/logs
      - ./config:/app/config
    ports:
      - "8080:8080"
    depends_on:
      - redis
    networks:
      - backup-network

  redis:
    image: redis:7-alpine
    container_name: nextcloud-backup-redis
    restart: unless-stopped
    volumes:
      - redis_data:/data
    networks:
      - backup-network

  web-interface:
    build: .
    container_name: nextcloud-backup-web
    restart: unless-stopped
    ports:
      - "8081:8081"
    environment:
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis
    networks:
      - backup-network

volumes:
  redis_data:

networks:
  backup-network:
    driver: bridge
EOF

# Crear Dockerfile
sudo tee Dockerfile > /dev/null << 'EOF'
FROM python:3.11-slim

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    inotify-tools \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de trabajo
WORKDIR /app

# Copiar requirements
COPY requirements.txt .

# Instalar dependencias de Python
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código fuente
COPY . .

# Crear directorios necesarios
RUN mkdir -p /app/logs /app/config

# Hacer ejecutables los scripts
RUN chmod +x /app/start.sh

# Exponer puertos
EXPOSE 8080 8081

# Comando por defecto
CMD ["./start.sh"]
EOF

# Crear requirements.txt
sudo tee requirements.txt > /dev/null << 'EOF'
requests==2.31.0
python-telegram-bot==20.7
watchdog==3.0.0
redis==5.0.1
flask==3.0.0
python-dotenv==1.0.0
Pillow==10.1.0
EOF

# Crear start.sh
sudo tee start.sh > /dev/null << 'EOF'
#!/bin/bash

# Iniciar el bot de respaldo y la interfaz web en paralelo
python3 backup_bot.py &
python3 web_interface.py &

# Esperar a que terminen los procesos
wait
EOF

sudo chmod +x start.sh

# Crear directorios necesarios
sudo mkdir -p logs config templates

# Crear archivo .env
echo "📝 Configurando variables de entorno..."

read -p "🔑 Ingresa el token de tu bot de Telegram: " BOT_TOKEN
read -p "💬 Ingresa el ID del chat/grupo de Telegram: " CHAT_ID
read -p "📁 Ingresa la ruta completa del directorio de datos de Nextcloud: " NEXTCLOUD_PATH

# Validar que la ruta de Nextcloud existe
if [ ! -d "$NEXTCLOUD_PATH" ]; then
    echo "❌ La ruta de Nextcloud no existe: $NEXTCLOUD_PATH"
    echo "Por favor verifica la ruta e intenta de nuevo."
    exit 1
fi

# Crear archivo .env
sudo tee .env > /dev/null << EOF
TELEGRAM_BOT_TOKEN=$BOT_TOKEN
TELEGRAM_CHAT_ID=$CHAT_ID
NEXTCLOUD_DATA_PATH=$NEXTCLOUD_PATH
LOG_LEVEL=INFO
REDIS_URL=redis://redis:6379
EOF

echo "✅ Archivo .env creado"

# Crear archivos Python (simplificados para el script)
echo "📄 Creando archivos Python..."

# Crear backup_bot.py (versión simplificada)
sudo tee backup_bot.py > /dev/null << 'EOF'
#!/usr/bin/env python3
import os
import sys
import time
import logging
import hashlib
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional

import requests
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import redis
from dotenv import load_dotenv

load_dotenv()

TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN')
TELEGRAM_CHAT_ID = os.getenv('TELEGRAM_CHAT_ID')
NEXTCLOUD_PATH = os.getenv('NEXTCLOUD_PATH', '/nextcloud/data')
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/backup_bot.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

try:
    redis_client = redis.Redis(host='redis', port=6379, db=0, decode_responses=True)
    redis_client.ping()
    logger.info("Conectado a Redis exitosamente")
except Exception as e:
    logger.error(f"Error conectando a Redis: {e}")
    redis_client = None

class FileProcessor:
    def __init__(self):
        self.supported_extensions = {
            '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp', '.svg',
            '.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.mkv', '.m4v',
            '.pdf', '.doc', '.docx', '.txt', '.rtf',
            '.mp3', '.wav', '.flac', '.aac', '.ogg'
        }
        
    def get_file_type(self, file_path: str) -> str:
        ext = Path(file_path).suffix.lower()
        if ext in ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp', '.svg']:
            return 'imagen'
        elif ext in ['.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.mkv', '.m4v']:
            return 'video'
        elif ext in ['.pdf', '.doc', '.docx', '.txt', '.rtf']:
            return 'documento'
        elif ext in ['.mp3', '.wav', '.flac', '.aac', '.ogg']:
            return 'audio'
        else:
            return 'archivo'
    
    def generate_hashtags(self, file_path: str) -> List[str]:
        file_name = Path(file_path).name
        file_type = self.get_file_type(file_path)
        file_ext = Path(file_path).suffix.lower().replace('.', '')
        
        hashtags = [
            f"#{file_type}",
            f"#{file_ext}",
            f"#{file_name.replace(' ', '_').replace('.', '_')}"
        ]
        
        if file_type == 'imagen':
            hashtags.extend(['#foto', '#imagen'])
        elif file_type == 'video':
            hashtags.extend(['#video', '#grabacion'])
        elif file_type == 'documento':
            hashtags.extend(['#documento', '#archivo'])
        elif file_type == 'audio':
            hashtags.extend(['#audio', '#musica'])
            
        return hashtags
    
    def should_process_file(self, file_path: str) -> bool:
        if not os.path.isfile(file_path):
            return False
        ext = Path(file_path).suffix.lower()
        return ext in self.supported_extensions
    
    def get_file_hash(self, file_path: str) -> str:
        hash_md5 = hashlib.md5()
        try:
            with open(file_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_md5.update(chunk)
            return hash_md5.hexdigest()
        except Exception as e:
            logger.error(f"Error calculando hash de {file_path}: {e}")
            return ""

class TelegramBot:
    def __init__(self, bot_token: str, chat_id: str):
        self.bot_token = bot_token
        self.chat_id = chat_id
        self.base_url = f"https://api.telegram.org/bot{bot_token}"
        
    def send_file(self, file_path: str, caption: str = "") -> bool:
        try:
            file_size = os.path.getsize(file_path)
            
            if file_size > 50 * 1024 * 1024:  # 50MB
                logger.warning(f"Archivo {file_path} demasiado grande ({file_size} bytes)")
                return False
            
            with open(file_path, 'rb') as file:
                files = {'document': file}
                data = {
                    'chat_id': self.chat_id,
                    'caption': caption,
                    'parse_mode': 'HTML'
                }
                
                response = requests.post(
                    f"{self.base_url}/sendDocument",
                    files=files,
                    data=data,
                    timeout=300
                )
                
                if response.status_code == 200:
                    result = response.json()
                    if result.get('ok'):
                        logger.info(f"Archivo enviado exitosamente: {file_path}")
                        return True
                    else:
                        logger.error(f"Error de Telegram API: {result}")
                        return False
                else:
                    logger.error(f"Error HTTP {response.status_code}: {response.text}")
                    return False
                    
        except Exception as e:
            logger.error(f"Error enviando archivo {file_path}: {e}")
            return False

class NextcloudFileHandler(FileSystemEventHandler):
    def __init__(self):
        self.file_processor = FileProcessor()
        self.telegram_bot = TelegramBot(TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID)
        self.processing_queue = []
        self.processed_files = set()
        
    def on_created(self, event):
        if not event.is_directory:
            self._process_file(event.src_path)
    
    def on_moved(self, event):
        if not event.is_directory:
            self._process_file(event.dest_path)
    
    def _process_file(self, file_path: str):
        try:
            time.sleep(2)
            
            if not self.file_processor.should_process_file(file_path):
                logger.debug(f"Archivo no soportado, omitiendo: {file_path}")
                return
            
            file_hash = self.file_processor.get_file_hash(file_path)
            if file_hash in self.processed_files:
                logger.debug(f"Archivo ya procesado, omitiendo: {file_path}")
                return
            
            self.processing_queue.append({
                'file_path': file_path,
                'file_hash': file_hash,
                'timestamp': datetime.now().isoformat(),
                'status': 'pending'
            })
            
            if redis_client:
                redis_client.lpush('processing_queue', json.dumps({
                    'file_path': file_path,
                    'file_hash': file_hash,
                    'timestamp': datetime.now().isoformat(),
                    'status': 'pending'
                }))
            
            logger.info(f"Archivo agregado a la cola: {file_path}")
            
        except Exception as e:
            logger.error(f"Error procesando archivo {file_path}: {e}")
    
    def process_queue(self):
        while self.processing_queue:
            file_info = self.processing_queue.pop(0)
            file_path = file_info['file_path']
            
            try:
                if not os.path.exists(file_path):
                    logger.warning(f"Archivo no encontrado: {file_path}")
                    continue
                
                hashtags = self.file_processor.generate_hashtags(file_path)
                file_name = Path(file_path).name
                file_type = self.file_processor.get_file_type(file_path)
                
                caption = f"📁 <b>{file_name}</b>\n"
                caption += f"📂 Tipo: {file_type.title()}\n"
                caption += f"📅 Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
                caption += f"🏷️ {' '.join(hashtags)}"
                
                success = self.telegram_bot.send_file(file_path, caption)
                
                if success:
                    self.processed_files.add(file_info['file_hash'])
                    
                    if redis_client:
                        redis_client.lpush('processed_files', json.dumps({
                            'file_path': file_path,
                            'file_hash': file_info['file_hash'],
                            'timestamp': datetime.now().isoformat(),
                            'status': 'completed'
                        }))
                    
                    logger.info(f"Archivo procesado exitosamente: {file_path}")
                else:
                    logger.error(f"Error enviando archivo: {file_path}")
                    
                    file_info['status'] = 'failed'
                    file_info['retry_count'] = file_info.get('retry_count', 0) + 1
                    
                    if file_info['retry_count'] < 3:
                        self.processing_queue.append(file_info)
                        logger.info(f"Reintentando archivo en 30 segundos: {file_path}")
                        time.sleep(30)
                
            except Exception as e:
                logger.error(f"Error procesando archivo de la cola {file_path}: {e}")

def main():
    logger.info("Iniciando bot de respaldo de Nextcloud a Telegram")
    
    if not os.path.exists(NEXTCLOUD_PATH):
        logger.error(f"Directorio de Nextcloud no encontrado: {NEXTCLOUD_PATH}")
        sys.exit(1)
    
    event_handler = NextcloudFileHandler()
    observer = Observer()
    
    observer.schedule(event_handler, NEXTCLOUD_PATH, recursive=True)
    observer.start()
    logger.info(f"Monitoreando directorio: {NEXTCLOUD_PATH}")
    
    try:
        while True:
            event_handler.process_queue()
            time.sleep(5)
            
    except KeyboardInterrupt:
        logger.info("Deteniendo bot...")
        observer.stop()
    
    observer.join()
    logger.info("Bot detenido")

if __name__ == "__main__":
    main()
EOF

# Crear web_interface.py (versión simplificada)
sudo tee web_interface.py > /dev/null << 'EOF'
#!/usr/bin/env python3
import os
import json
import logging
from datetime import datetime
from typing import List, Dict

import redis
from flask import Flask, render_template, jsonify, request
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

try:
    redis_client = redis.Redis(host='redis', port=6379, db=0, decode_responses=True)
    redis_client.ping()
    logger.info("Conectado a Redis exitosamente")
except Exception as e:
    logger.error(f"Error conectando a Redis: {e}")
    redis_client = None

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/status')
def get_status():
    try:
        if not redis_client:
            return jsonify({'error': 'Redis no disponible'}), 500
        
        queue_length = redis_client.llen('processing_queue')
        processed_count = redis_client.llen('processed_files')
        
        recent_processed = []
        if processed_count > 0:
            recent_data = redis_client.lrange('processed_files', 0, 9)
            recent_processed = [json.loads(item) for item in recent_data]
        
        return jsonify({
            'queue_length': queue_length,
            'processed_count': processed_count,
            'recent_processed': recent_processed,
            'status': 'running' if redis_client else 'error'
        })
        
    except Exception as e:
        logger.error(f"Error obteniendo estado: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/queue')
def get_queue():
    try:
        if not redis_client:
            return jsonify({'error': 'Redis no disponible'}), 500
        
        queue_data = redis_client.lrange('processing_queue', 0, -1)
        queue_items = [json.loads(item) for item in queue_data]
        
        return jsonify({
            'queue': queue_items,
            'count': len(queue_items)
        })
        
    except Exception as e:
        logger.error(f"Error obteniendo cola: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/processed')
def get_processed():
    try:
        if not redis_client:
            return jsonify({'error': 'Redis no disponible'}), 500
        
        page = int(request.args.get('page', 1))
        per_page = int(request.args.get('per_page', 20))
        
        start = (page - 1) * per_page
        end = start + per_page - 1
        
        processed_data = redis_client.lrange('processed_files', start, end)
        processed_items = [json.loads(item) for item in processed_data]
        
        total_count = redis_client.llen('processed_files')
        
        return jsonify({
            'processed': processed_items,
            'count': len(processed_items),
            'total_count': total_count,
            'page': page,
            'per_page': per_page,
            'total_pages': (total_count + per_page - 1) // per_page
        })
        
    except Exception as e:
        logger.error(f"Error obteniendo archivos procesados: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/clear_queue', methods=['POST'])
def clear_queue():
    try:
        if not redis_client:
            return jsonify({'error': 'Redis no disponible'}), 500
        
        redis_client.delete('processing_queue')
        return jsonify({'message': 'Cola limpiada exitosamente'})
        
    except Exception as e:
        logger.error(f"Error limpiando cola: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/clear_processed', methods=['POST'])
def clear_processed():
    try:
        if not redis_client:
            return jsonify({'error': 'Redis no disponible'}), 500
        
        redis_client.delete('processed_files')
        return jsonify({'message': 'Historial limpiado exitosamente'})
        
    except Exception as e:
        logger.error(f"Error limpiando historial: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    os.makedirs('templates', exist_ok=True)
    app.run(host='0.0.0.0', port=8081, debug=False)
EOF

# Crear template HTML
sudo tee templates/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bot de Respaldo Nextcloud - Telegram</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 15px; box-shadow: 0 20px 40px rgba(0,0,0,0.1); overflow: hidden; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; }
        .header h1 { font-size: 2.5em; margin-bottom: 10px; }
        .header p { font-size: 1.2em; opacity: 0.9; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; padding: 30px; background: #f8f9fa; }
        .stat-card { background: white; padding: 25px; border-radius: 10px; text-align: center; box-shadow: 0 5px 15px rgba(0,0,0,0.08); transition: transform 0.3s ease; }
        .stat-card:hover { transform: translateY(-5px); }
        .stat-number { font-size: 2.5em; font-weight: bold; color: #667eea; margin-bottom: 10px; }
        .stat-label { color: #666; font-size: 1.1em; }
        .content { padding: 30px; }
        .section { margin-bottom: 40px; }
        .section h2 { color: #333; margin-bottom: 20px; font-size: 1.8em; border-bottom: 3px solid #667eea; padding-bottom: 10px; }
        .queue-item, .processed-item { background: #f8f9fa; border: 1px solid #e9ecef; border-radius: 8px; padding: 15px; margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center; transition: background-color 0.3s ease; }
        .queue-item:hover, .processed-item:hover { background: #e9ecef; }
        .file-info { flex: 1; }
        .file-name { font-weight: bold; color: #333; margin-bottom: 5px; }
        .file-details { color: #666; font-size: 0.9em; }
        .file-status { padding: 5px 15px; border-radius: 20px; font-size: 0.8em; font-weight: bold; text-transform: uppercase; }
        .status-pending { background: #fff3cd; color: #856404; }
        .status-completed { background: #d4edda; color: #155724; }
        .controls { display: flex; gap: 10px; margin-bottom: 20px; }
        .btn { padding: 10px 20px; border: none; border-radius: 5px; cursor: pointer; font-size: 1em; transition: all 0.3s ease; }
        .btn-primary { background: #667eea; color: white; }
        .btn-primary:hover { background: #5a6fd8; }
        .btn-danger { background: #dc3545; color: white; }
        .btn-danger:hover { background: #c82333; }
        .loading { text-align: center; padding: 20px; color: #666; }
        .error { background: #f8d7da; color: #721c24; padding: 15px; border-radius: 5px; margin: 10px 0; }
        .success { background: #d4edda; color: #155724; padding: 15px; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🤖 Bot de Respaldo Nextcloud</h1>
            <p>Monitoreo de archivos enviados a Telegram</p>
        </div>
        <div class="stats">
            <div class="stat-card">
                <div class="stat-number" id="queue-count">-</div>
                <div class="stat-label">Archivos en Cola</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="processed-count">-</div>
                <div class="stat-label">Archivos Procesados</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" id="status-indicator">-</div>
                <div class="stat-label">Estado del Sistema</div>
            </div>
        </div>
        <div class="content">
            <div class="section">
                <h2>📋 Cola de Procesamiento</h2>
                <div class="controls">
                    <button class="btn btn-primary" onclick="refreshQueue()">🔄 Actualizar</button>
                    <button class="btn btn-danger" onclick="clearQueue()">🗑️ Limpiar Cola</button>
                </div>
                <div id="queue-container">
                    <div class="loading">Cargando cola...</div>
                </div>
            </div>
            <div class="section">
                <h2>✅ Archivos Procesados</h2>
                <div class="controls">
                    <button class="btn btn-primary" onclick="refreshProcessed()">🔄 Actualizar</button>
                    <button class="btn btn-danger" onclick="clearProcessed()">🗑️ Limpiar Historial</button>
                </div>
                <div id="processed-container">
                    <div class="loading">Cargando archivos procesados...</div>
                </div>
            </div>
        </div>
    </div>
    <script>
        function formatDate(dateString) {
            const date = new Date(dateString);
            return date.toLocaleString('es-ES');
        }
        async function updateStatus() {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                if (data.error) throw new Error(data.error);
                document.getElementById('queue-count').textContent = data.queue_length;
                document.getElementById('processed-count').textContent = data.processed_count;
                document.getElementById('status-indicator').textContent = data.status === 'running' ? '🟢 Activo' : '🔴 Error';
            } catch (error) {
                console.error('Error actualizando estado:', error);
                document.getElementById('status-indicator').textContent = '🔴 Error';
            }
        }
        async function refreshQueue() {
            const container = document.getElementById('queue-container');
            container.innerHTML = '<div class="loading">Cargando cola...</div>';
            try {
                const response = await fetch('/api/queue');
                const data = await response.json();
                if (data.error) throw new Error(data.error);
                if (data.queue.length === 0) {
                    container.innerHTML = '<div class="success">✅ No hay archivos en cola</div>';
                } else {
                    container.innerHTML = data.queue.map(item => `
                        <div class="queue-item">
                            <div class="file-info">
                                <div class="file-name">${item.file_path.split('/').pop()}</div>
                                <div class="file-details">Agregado: ${formatDate(item.timestamp)}</div>
                            </div>
                            <div class="file-status status-pending">Pendiente</div>
                        </div>
                    `).join('');
                }
            } catch (error) {
                container.innerHTML = `<div class="error">❌ Error: ${error.message}</div>`;
            }
        }
        async function refreshProcessed() {
            const container = document.getElementById('processed-container');
            container.innerHTML = '<div class="loading">Cargando archivos procesados...</div>';
            try {
                const response = await fetch('/api/processed');
                const data = await response.json();
                if (data.error) throw new Error(data.error);
                if (data.processed.length === 0) {
                    container.innerHTML = '<div class="success">✅ No hay archivos procesados</div>';
                } else {
                    container.innerHTML = data.processed.map(item => `
                        <div class="processed-item">
                            <div class="file-info">
                                <div class="file-name">${item.file_path.split('/').pop()}</div>
                                <div class="file-details">Procesado: ${formatDate(item.timestamp)}</div>
                            </div>
                            <div class="file-status status-completed">Completado</div>
                        </div>
                    `).join('');
                }
            } catch (error) {
                container.innerHTML = `<div class="error">❌ Error: ${error.message}</div>`;
            }
        }
        async function clearQueue() {
            if (!confirm('¿Estás seguro de que quieres limpiar la cola de procesamiento?')) return;
            try {
                const response = await fetch('/api/clear_queue', { method: 'POST' });
                const data = await response.json();
                if (data.error) throw new Error(data.error);
                alert('Cola limpiada exitosamente');
                refreshQueue();
                updateStatus();
            } catch (error) {
                alert(`Error: ${error.message}`);
            }
        }
        async function clearProcessed() {
            if (!confirm('¿Estás seguro de que quieres limpiar el historial de archivos procesados?')) return;
            try {
                const response = await fetch('/api/clear_processed', { method: 'POST' });
                const data = await response.json();
                if (data.error) throw new Error(data.error);
                alert('Historial limpiado exitosamente');
                refreshProcessed();
                updateStatus();
            } catch (error) {
                alert(`Error: ${error.message}`);
            }
        }
        document.addEventListener('DOMContentLoaded', function() {
            updateStatus();
            refreshQueue();
            refreshProcessed();
            setInterval(() => {
                updateStatus();
                refreshQueue();
            }, 30000);
        });
    </script>
</body>
</html>
EOF

echo "✅ Archivos creados exitosamente"

# Construir y ejecutar los contenedores
echo "🔨 Construyendo contenedores Docker..."
sudo docker-compose build

echo "🚀 Iniciando servicios..."
sudo docker-compose up -d

# Esperar a que los servicios estén listos
echo "⏳ Esperando a que los servicios estén listos..."
sleep 10

# Verificar que los servicios estén ejecutándose
echo "🔍 Verificando estado de los servicios..."
sudo docker-compose ps

echo ""
echo "🎉 ¡Instalación completada exitosamente!"
echo ""
echo "📋 Información de acceso:"
echo "   • Interfaz Web: http://$(hostname -I | awk '{print $1}'):8081"
echo "   • Logs del Bot: sudo docker-compose logs -f nextcloud-backup-bot"
echo "   • Estado: sudo docker-compose ps"
echo ""
echo "🔧 Comandos útiles:"
echo "   • Detener: sudo docker-compose down"
echo "   • Reiniciar: sudo docker-compose restart"
echo "   • Ver logs: sudo docker-compose logs -f"
echo ""
echo "📁 Archivos de configuración:"
echo "   • Directorio: $PROJECT_DIR"
echo "   • Configuración: $PROJECT_DIR/.env"
echo "   • Logs: $PROJECT_DIR/logs/"
echo ""
echo "✅ El bot está monitoreando: $NEXTCLOUD_PATH"
echo "📱 Los archivos se enviarán al chat: $CHAT_ID"
echo ""
echo "¡Disfruta de tu bot de respaldo automático! 🚀"
