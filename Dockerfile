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
