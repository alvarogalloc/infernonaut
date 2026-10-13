INFERNONAUT - UNIDADES Y ESPECIFICACIONES DE SALAS
==================================================

1. UNIDADES BASE
----------------
- 1 tile (UT)      = 60 x 60 px = 2 x 2 m
- 1 unidad de sala (US) = 32 x 18 tiles = viewport = 1920 x 1080 px
- Escala de mundo  = 30 px / metro
- Tamaño de tile propuesto y usado: 60 px (hace que el viewport de la
  GDD, 1920x1080, sea exactamente 32x18 tiles, sin recortes).
- Todos los elementos (jugador, enemigos, pinchos, puertas) se miden en
  tiles: mantener múltiplos de 60 px.

2. TIPOS DE SALA (n x m unidades de sala)
-----------------------------------------
  tipo   cámara
  1x1    fija en el centro (la sala = viewport)
  nx1    fija en Y, sigue al jugador en X (clamp a los bordes)
  1xn    fija en X, sigue al jugador en Y (clamp a los bordes)
  nxm    sigue al jugador en ambos ejes (clamp a los bordes)
  Salas raras (L, T, +) = varios rectángulos que encajan en los casos
  anteriores (regla de la GDD: si el jugador está en dos rects a la vez,
  no cambiar de rect; es zona de solape).

3. REGLAS DE CÁMARA
-------------------
- Zoom FIJO: 1x1 llena la pantalla. Salas mayores hacen PAN, nunca zoom-out.
- El cambio de sala lo dispara la cámara al entrar en el marco de una sala
  vecina; el gestor de transición hace wipe + teletransporte a la sala nueva.
- Al aterrizar no se pisa el marco de otra sala (evita ping-pong).

4. ESTRUCTURA DEL JUEGO (runtime)
----------------------------------
- Escena principal: res://scenes/juego/juego.tscn (menú -> carga -> nivel).
  Menú aislado: res://scenes/juego/menu_principal.tscn
  Carga aislada: res://scenes/juego/pantalla_carga.tscn (barra animada)
- El nivel NO se guarda: se genera en runtime con
  res://scenes/nivel/generador_nivel.gd
  (GeneradorNivel.generar(semilla, plantilla, densidad_enemigos)).
  Verifica que el nivel sea un solo componente conexo (siempre pasable) y
  reintenta con otra sub-semilla si no lo es.
- `densidad_enemigos` (float, 1.0 = base) escala cuántos enemigos pone cada
  sala; `scenes/juego/juego.gd` lo expone con @export.
- 2 plantillas curadas (0 = 5 salas; 1 = bloque 3x2) + contenido por
  arquetipo de sala (inicio/combate/trampa/tesoro/meta) según la distancia
  a la sala inicial. Laberintos DFS distintos por semilla.
- TileSet blockout embebido: res://tile_sets/blockout.png (60 px, capa 4 pared).

5. GRUPOS / CAPAS DE FÍSICA (project.godot)
-------------------------------------------
  1 jugador | 2 dash | 3 enemigo | 4 pared | 5 daño | 6 colisión pared
  7 activar | 8 pinchos

6. DASHES (movimiento y ataque = mismo gesto)
---------------------------------------------
Unidad de referencia: 1 tile = 60 px = 2 m.
- Dash fuerte (click izq, ataque, gasta 1 vial de sangre): 10 tiles = 600 px = 20 m
- Dash normal (click der, solo movimiento): 5 tiles = 300 px = 10 m
- Cada click = UN dash discreto (no hay movimiento continuo). El trayecto se
  interpola con un Tween (ease-out) y la física lo aplica con move_and_slide,
  así las paredes siguen bloqueando.
- Duración a distancia máxima: fuerte 0.30 s, normal 0.22 s; escala con la
  distancia (mínimo 0.6x) para que los dashes cortos no se sientan lentos.
- Daño: SOLO el dash fuerte activa la hitbox de ataque. El normal NO daña
  enemigos (y deja al jugador vulnerable). Color: fuerte ROJO, normal AZUL.
- Al chocar con una pared el dash DESLIZA (move_and_slide), no se corta.
- Feedback: estiramiento direccional al salir, emisión de partículas teñida
  (rojo/azul) y dramática, aplastado al aterrizar, sonido (placeholder en
  sfx/) y rumble de mando. Sin luz ni espectáculos de pantalla.
- Tunables en res://scenes/personaje/character_body_2d.gd (grupos "Dash ...").
- Polling de dash corto: hasta 4 (COLA_MAX) clics derechos se encolan y se
  ejecutan uno tras otro al terminar el actual (facilita desplazarse).

7. LUZ, ENEMIGOS Y NIVEL
------------------------
- El jugador NO tiene luz (se quitó el PointLight y también el gradiente).
  El dash se lee por sus partículas. Point lights SOLO en las antorchas
  animadas del nivel (torch.tscn).
- Enemigo: partículas de muerte (sangre) al morir y radio de activación más
  grande (2200 px ≈ 36 tiles) para que persiga desde más lejos (más difícil).
- Nivel proto = laberintos: cada sala se divide en celdas de 3x3 tiles con
  pasillos de 3 tiles, conectadas por DFS (conectividad garantizada). Las
  puertas se conectan al laberinto con un camino (tile PATH). Decoración estilo
  cámara infernal/castillo: muros de piedra con vetas, piso sangriento,
  antorchas, pinchos y enemigos. La META está en la sala_3x1.
- El test assert_proto verifica que TODO el nivel es un solo componente conexo.

8. PUERTAS BLOQUEADAS POR ENEMIGOS
------------------------------------
- Cada conexión entre salas genera UNA barrera (scenes/nivel/puerta.gd,
  class_name Puerta) hija de la sala dueña: 2x2 tiles, collision_layer 4
  (pared), sprite res://sprites/puerta.png.
- Cada sala tiene un controlador (scenes/nivel/sala.gd, class_name Sala).
  Cuenta sus enemigos (señal `murio` de enemigo_1.gd) y abre TODAS sus
  puertas cuando no queda ninguno vivo. Una puerta ya abierta desactiva su
  colisión y se desvanece.
- Regla de retirada: la conexión A->B está bloqueada hasta limpiar A (la
  puerta la posee A). Al limpiar A se puede cruzar a B; las puertas de B
  siguen cerradas hasta limpiar B.
- La barrera cerrada mantiene al jugador fuera del marco de la sala vecina
  (> puerta_margen), así que no hay cambio de cámara sin haber limpiado.
- Test: tests/assert_puertas.gd (barreras por conexión, cierre inicial,
  apertura al matar, y escalado de densidad).

9. MATERIAL SIN USO
-------------------
- Los ficheros que no usa ni el juego ni los tests viven en `unused/`
  (con `unused/.gdignore` para que Godot ni los importe). Incluye el addon
  phantom_camera (no activado) y assets antiguos (ghost, tile_sets viejos,
  sprites sueltos, spritesheets de Infernonaut/Mentiroso no usados).

10. ESCALAS DE ENTIDADES (alineadas a la unidad)
-------------------------------------------------
1 tile = 60 px = 2 m. Referencia de diseño para el arte; el valor real vive
en la escala de cada .tscn (jugador, enemigos, pincho, antorcha, meta), porque
los sprites traen padding y se calibra por el tamaño jugable (hitbox).

