# Jueguito - Simulador de mundo

Proyecto de videojuego 2D desarrollado con Godot Engine.

## Descripción

Un simulador de mundo en el que se genera un entorno explorable
con diferentes tipos de terreno y recursos naturales.

## Tecnologías

- Godot Engine 4
- GDScript
- Pixelorama

## Licencias

- Código fuente: MIT License.
- Recursos gráficos originales: CC BY 4.0.

Consulta los archivos `LICENSE` y `assets/LICENSE` para conocer
las condiciones de uso y distribución.

## Autores

Keiler Ferrer, Sofia Paiva

## Estado

En desarrollo.

## Mundos

En Jugar se pueden buscar mundos y crear uno indicando nombre, semilla y
dificultad. Una semilla vacía se genera automáticamente y aparece en el campo
antes de guardarse. Se admiten enteros de -2147483648 a 2147483247: el
generador emplea semillas de 32 bits y suma desplazamientos de hasta 400.
La semilla guardada también se consulta pasando el cursor sobre el mundo en la
lista de selección.

Cada mundo se guarda como JSON en `user://mundos/`, con un identificador
independiente del nombre. «Guardar y salir» guarda la posición del jugador y la
fecha del último guardado mediante un archivo temporal antes de reemplazar el
anterior. Los mundos antiguos sin posición siguen siendo compatibles. Al volver
a jugar se reconstruye el terreno a partir de la semilla y se restaura la
posición. **No es un guardado completo**: no se recuperan cambios del terreno,
recursos ni criaturas; todavía no hay inventario persistente. Existe un campo
reservado para cambios futuros. La dificultad se guarda, pero sus ajustes son
marcadores pendientes de balance y no modifican las mecánicas actuales.

La carga utiliza `ResourceLoader` asíncrono y genera nodos en el hilo principal
por lotes. El porcentaje es una ponderación de trabajo completado, no tiempo
estimado: recursos de escena 0–10 %, filas de terreno 10–40 %, copias del
terreno 40–45 %, filas de recursos 45–80 %, copias de recursos 80–99 %, y
preparación del jugador y cámara 100 %. La barra usa los cuatro fotogramas
de 25, 50, 75 y 100 %; antes de 25 % permanece en el primer fotograma mientras
el texto indica el progreso real. Los fotogramas avanzan siempre en orden.
La duplicación de cada capa de terreno individual no es subdivisible y puede
producir pausas breves. La pantalla de carga nunca habilita al jugador antes
de que se complete la generación.

Orbitron Medium procede de Google Fonts y se distribuye bajo SIL OFL 1.1,
incluida en `recursos_interfaz/fuentes/OFL-Orbitron.txt`. La licencia permite
uso comercial y redistribución con el aviso de copyright y la licencia incluidos.

Los tiempos de los fondos están en `script/interfaz/gestor_fondos.gd`:
`intervalo` (10 segundos) y `duracion_transicion` (1,5 segundos).

Prueba automatizada (con un directorio de datos de usuario aislado):

```sh
XDG_DATA_HOME=/tmp/opencode/stranded-test godot --headless --path . --script res://tests/interfaz_mundos.gd
XDG_DATA_HOME=/tmp/opencode/stranded-test godot --headless --path . --script res://tests/inicio_mundo.gd
```
