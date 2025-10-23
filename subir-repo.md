# 📤 Cómo Subir el Proyecto a GitHub

## Opción 1: Instalar Git y usar comandos

### 1. Instalar Git en Windows
```bash
# Descargar Git desde: https://git-scm.com/download/win
# O usar winget:
winget install Git.Git
```

### 2. Configurar Git
```bash
git config --global user.name "Tu Nombre"
git config --global user.email "tu@email.com"
```

### 3. Subir el proyecto
```bash
# Inicializar repositorio
git init

# Agregar archivos
git add .

# Commit inicial
git commit -m "Initial commit: Bot de respaldo Nextcloud a Telegram"

# Agregar repositorio remoto
git remote add origin https://github.com/FranderProg/nextcloud-telegram-backup.git

# Subir archivos
git push -u origin main
```

## Opción 2: Subir archivos manualmente

### 1. Ir a GitHub
Ve a: https://github.com/FranderProg/nextcloud-telegram-backup

### 2. Subir archivos uno por uno
1. Haz clic en "Add file" → "Upload files"
2. Arrastra todos los archivos del proyecto
3. Escribe un mensaje de commit: "Initial commit: Bot de respaldo Nextcloud a Telegram"
4. Haz clic en "Commit changes"

### 3. Archivos a subir:
- `backup_bot.py`
- `web_interface.py`
- `docker-compose.yml`
- `Dockerfile`
- `requirements.txt`
- `start.sh`
- `templates/index.html`
- `install.sh`
- `casaos-app.json`
- `README.md`
- `INSTALACION.md`
- `env.example`
- `.gitignore`

## Opción 3: Usar GitHub Desktop

### 1. Instalar GitHub Desktop
Descargar desde: https://desktop.github.com/

### 2. Clonar repositorio
1. Abre GitHub Desktop
2. File → Clone repository
3. URL: `https://github.com/FranderProg/nextcloud-telegram-backup.git`
4. Selecciona carpeta local

### 3. Copiar archivos
1. Copia todos los archivos del proyecto a la carpeta clonada
2. GitHub Desktop detectará los cambios
3. Escribe mensaje de commit
4. Haz clic en "Commit to main"
5. Haz clic en "Push origin"

## 📋 Lista de Archivos del Proyecto

```
nextcloud-telegram-backup/
├── backup_bot.py              # Bot principal
├── web_interface.py           # Interfaz web
├── docker-compose.yml         # Configuración Docker
├── Dockerfile                 # Imagen Docker
├── requirements.txt           # Dependencias Python
├── start.sh                   # Script de inicio
├── install.sh                 # Script de instalación
├── casaos-app.json           # Configuración CasaOS
├── templates/
│   └── index.html            # Template web
├── README.md                 # Documentación
├── INSTALACION.md            # Guía de instalación
├── env.example               # Variables de entorno
├── .gitignore               # Archivos a ignorar
└── subir-repo.md            # Esta guía
```

## 🎯 Después de subir

### 1. Actualizar README
El README.md ya está configurado con:
- Descripción del proyecto
- Instrucciones de instalación
- Características
- Solución de problemas

### 2. Crear Release
1. Ve a "Releases" en GitHub
2. "Create a new release"
3. Tag: `v1.0.0`
4. Título: "Bot de Respaldo Nextcloud a Telegram v1.0.0"
5. Descripción: "Primera versión del bot automático de respaldo"

### 3. Configurar GitHub Pages (Opcional)
Para documentación web:
1. Settings → Pages
2. Source: Deploy from a branch
3. Branch: main
4. Folder: / (root)

## 🔗 Enlaces Útiles

- **Repositorio**: https://github.com/FranderProg/nextcloud-telegram-backup
- **Issues**: Para reportar problemas
- **Releases**: Para descargar versiones
- **Wiki**: Para documentación adicional

## 📝 Próximos Pasos

1. ✅ Subir archivos a GitHub
2. ✅ Crear primera release
3. ✅ Probar instalación
4. ✅ Documentar uso
5. ✅ Compartir con la comunidad

¡Tu bot de respaldo estará disponible para que otros lo usen! 🚀
