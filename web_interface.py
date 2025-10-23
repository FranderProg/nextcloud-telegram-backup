#!/usr/bin/env python3
"""
Interfaz web para monitorear el bot de respaldo de Nextcloud
Muestra archivos en cola, progreso y archivos procesados
"""

import os
import json
import logging
from datetime import datetime
from typing import List, Dict

import redis
from flask import Flask, render_template, jsonify, request
from dotenv import load_dotenv

# Cargar variables de entorno
load_dotenv()

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configurar Flask
app = Flask(__name__)

# Conectar a Redis
try:
    redis_client = redis.Redis(host='redis', port=6379, db=0, decode_responses=True)
    redis_client.ping()
    logger.info("Conectado a Redis exitosamente")
except Exception as e:
    logger.error(f"Error conectando a Redis: {e}")
    redis_client = None

@app.route('/')
def index():
    """Página principal"""
    return render_template('index.html')

@app.route('/api/status')
def get_status():
    """Obtiene el estado general del sistema"""
    try:
        if not redis_client:
            return jsonify({'error': 'Redis no disponible'}), 500
        
        # Obtener estadísticas
        queue_length = redis_client.llen('processing_queue')
        processed_count = redis_client.llen('processed_files')
        
        # Obtener archivos recientes
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
    """Obtiene la cola de archivos pendientes"""
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
    """Obtiene archivos procesados"""
    try:
        if not redis_client:
            return jsonify({'error': 'Redis no disponible'}), 500
        
        # Obtener parámetros de paginación
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
    """Limpia la cola de procesamiento"""
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
    """Limpia el historial de archivos procesados"""
    try:
        if not redis_client:
            return jsonify({'error': 'Redis no disponible'}), 500
        
        redis_client.delete('processed_files')
        
        return jsonify({'message': 'Historial limpiado exitosamente'})
        
    except Exception as e:
        logger.error(f"Error limpiando historial: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    # Crear directorio de templates si no existe
    os.makedirs('templates', exist_ok=True)
    
    # Ejecutar aplicación
    app.run(host='0.0.0.0', port=8081, debug=False)
