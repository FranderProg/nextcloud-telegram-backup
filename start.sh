#!/bin/bash

# Iniciar el bot de respaldo y la interfaz web en paralelo
python3 backup_bot.py &
python3 web_interface.py &

# Esperar a que terminen los procesos
wait
