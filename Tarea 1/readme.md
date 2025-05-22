# Tarea 1

Para correr esta tarea es necesario correr `./game.sh [mode]`, con mode pudiendo tener uno de los siguietes valores: name, content, checksum, encrypted o signed.

Para correr la tarea es necesario que este habilidated poder ser ejecutado por lo tanto si no se tiene que correr el siguiente comando `chmod +x game.sh`.

Finalmente para aseegurarse que todos los archivos tenga un nombre único, cuando se llama a `create_board`, se tiene una variable global que comienza en 1 y cuando se crea un archivo se suma 1. Por lo tanto si se crea un tablero con depth 1, width 5, y file 5, algunos archivos serían los siguiente,`dir0/file0.txt` y `dir0/file1.txt`, y en el último directorio `dir4/file23.txt` y `dir4/file24.txt`. De esta forma se asegura que todos los nombres de los files sean distintos.