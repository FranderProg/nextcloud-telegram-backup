#!/usr/bin/env python3
"""
Bot de respaldo automático de Nextcloud a Telegram
Monitorea archivos nuevos y los envía automáticamente a un grupo de Telegram
"""

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

# Cargar variables de entorno
load_dotenv()

# Configuración
TELEGRAM_BOT_TOKEN = os.getenv('TELEGRAM_BOT_TOKEN', '8397420823:AAHktLrj-Urqi4TpepZRtYcFqSN5p2QMp7o')
TELEGRAM_CHAT_ID = os.getenv('TELEGRAM_CHAT_ID', '5642423602')
NEXTCLOUD_PATH = os.getenv('NEXTCLOUD_PATH', '/nextcloud/data')
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')

# Configurar logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/app/logs/backup_bot.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Conectar a Redis
try:
    redis_client = redis.Redis(host='redis', port=6379, db=0, decode_responses=True)
    redis_client.ping()
    logger.info("Conectado a Redis exitosamente")
except Exception as e:
    logger.error(f"Error conectando a Redis: {e}")
    redis_client = None

class FileProcessor:
    """Procesador de archivos para envío a Telegram"""
    
    def __init__(self):
        self.supported_extensions = {
            # Imágenes
            '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp', '.svg',
            # Videos
            '.mp4', '.avi', '.mov', '.wmv', '.flv', '.webm', '.mkv', '.m4v',
            # Documentos
            '.pdf', '.doc', '.docx', '.txt', '.rtf',
            # Audio
            '.mp3', '.wav', '.flac', '.aac', '.ogg'
        }
        
    def get_file_type(self, file_path: str) -> str:
        """Determina el tipo de archivo basado en la extensión"""
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
        """Genera hashtags para el archivo"""
        file_name = Path(file_path).name
        file_type = self.get_file_type(file_path)
        file_ext = Path(file_path).suffix.lower().replace('.', '')
        
        hashtags = [
            f"#{file_type}",
            f"#{file_ext}",
            f"#{file_name.replace(' ', '_').replace('.', '_')}"
        ]
        
        # Agregar hashtags adicionales basados en el tipo
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
        """Determina si el archivo debe ser procesado"""
        if not os.path.isfile(file_path):
            return False
            
        ext = Path(file_path).suffix.lower()
        return ext in self.supported_extensions
    
    def get_file_hash(self, file_path: str) -> str:
        """Calcula el hash MD5 del archivo"""
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
    """Cliente para enviar archivos a Telegram"""
    
    def __init__(self, bot_token: str, chat_id: str):
        self.bot_token = bot_token
        self.chat_id = chat_id
        self.base_url = f"https://api.telegram.org/bot{bot_token}"
        
    def send_file(self, file_path: str, caption: str = "") -> bool:
        """Envía un archivo a Telegram"""
        try:
            file_size = os.path.getsize(file_path)
            
            # Telegram tiene límites de tamaño
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
                    timeout=300  # 5 minutos timeout
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
    
    def send_photo(self, file_path: str, caption: str = "") -> bool:
        """Envía una foto a Telegram (mantiene calidad)"""
        try:
            file_size = os.path.getsize(file_path)
            
            # Para fotos, usar sendPhoto pero como archivo para mantener calidad
            return self.send_file(file_path, caption)
                    
        except Exception as e:
            logger.error(f"Error enviando foto {file_path}: {e}")
            return False

class NextcloudFileHandler(FileSystemEventHandler):
    """Manejador de eventos del sistema de archivos de Nextcloud"""
    
    def __init__(self):
        self.file_processor = FileProcessor()
        self.telegram_bot = TelegramBot(TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID)
        self.processing_queue = []
        self.processed_files = set()
        
    def on_created(self, event):
        """Maneja la creación de nuevos archivos"""
        if not event.is_directory:
            self._process_file(event.src_path)
    
    def on_moved(self, event):
        """Maneja el movimiento de archivos"""
        if not event.is_directory:
            self._process_file(event.dest_path)
    
    def _process_file(self, file_path: str):
        """Procesa un archivo para envío"""
        try:
            # Esperar un poco para asegurar que el archivo esté completamente escrito
            time.sleep(2)
            
            if not self.file_processor.should_process_file(file_path):
                logger.debug(f"Archivo no soportado, omitiendo: {file_path}")
                return
            
            # Verificar si ya fue procesado
            file_hash = self.file_processor.get_file_hash(file_path)
            if file_hash in self.processed_files:
                logger.debug(f"Archivo ya procesado, omitiendo: {file_path}")
                return
            
            # Agregar a la cola de procesamiento
            self.processing_queue.append({
                'file_path': file_path,
                'file_hash': file_hash,
                'timestamp': datetime.now().isoformat(),
                'status': 'pending'
            })
            
            # Actualizar estado en Redis
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
        """Procesa la cola de archivos pendientes"""
        while self.processing_queue:
            file_info = self.processing_queue.pop(0)
            file_path = file_info['file_path']
            
            try:
                # Verificar que el archivo aún existe
                if not os.path.exists(file_path):
                    logger.warning(f"Archivo no encontrado: {file_path}")
                    continue
                
                # Generar hashtags y caption
                hashtags = self.file_processor.generate_hashtags(file_path)
                file_name = Path(file_path).name
                file_type = self.file_processor.get_file_type(file_path)
                
                caption = f"📁 <b>{file_name}</b>\n"
                caption += f"📂 Tipo: {file_type.title()}\n"
                caption += f"📅 Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
                caption += f"🏷️ {' '.join(hashtags)}"
                
                # Enviar archivo
                success = self.telegram_bot.send_file(file_path, caption)
                
                if success:
                    # Marcar como procesado
                    self.processed_files.add(file_info['file_hash'])
                    
                    # Actualizar estado en Redis
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
                    
                    # Reintentar más tarde
                    file_info['status'] = 'failed'
                    file_info['retry_count'] = file_info.get('retry_count', 0) + 1
                    
                    if file_info['retry_count'] < 3:
                        self.processing_queue.append(file_info)
                        logger.info(f"Reintentando archivo en 30 segundos: {file_path}")
                        time.sleep(30)
                
            except Exception as e:
                logger.error(f"Error procesando archivo de la cola {file_path}: {e}")

def main():
    """Función principal"""
    logger.info("Iniciando bot de respaldo de Nextcloud a Telegram")
    
    # Verificar que el directorio de Nextcloud existe
    if not os.path.exists(NEXTCLOUD_PATH):
        logger.error(f"Directorio de Nextcloud no encontrado: {NEXTCLOUD_PATH}")
        sys.exit(1)
    
    # Crear manejador de archivos
    event_handler = NextcloudFileHandler()
    observer = Observer()
    
    # Configurar observador
    observer.schedule(event_handler, NEXTCLOUD_PATH, recursive=True)
    
    # Iniciar observador
    observer.start()
    logger.info(f"Monitoreando directorio: {NEXTCLOUD_PATH}")
    
    try:
        while True:
            # Procesar cola de archivos
            event_handler.process_queue()
            time.sleep(5)  # Verificar cada 5 segundos
            
    except KeyboardInterrupt:
        logger.info("Deteniendo bot...")
        observer.stop()
    
    observer.join()
    logger.info("Bot detenido")

if __name__ == "__main__":
    main()
