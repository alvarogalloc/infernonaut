INFERNONAUT - UNIDADES, SALAS Y TUTORIAL
========================================

1. UNIDADES BASE
----------------
- 1 tile (UT)      = 60 x 60 px = 2 x 2 m
- 1 unidad de sala (US) = 32 x 18 tiles = viewport = 1920 x 1080 px
- Escala de mundo  = 30 px / metro
- Todos los elementos se miden en tiles: mantener múltiplos de 60 px.

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

4. ESTRUCTURA DEL JUEGO
-----------------------
- Escena principal: res://scenes/juego/juego.tscn (menú -> carga -> nivel).
- El nivel es CURADO, no generado: res://scenes/nivel/tutorial.gd contiene
  seis mapas fijos de 30x16 (interior) en una fila y los construye en runtime.
  Los mapas se editan como texto en el array MAPAS; cada carácter es una
  entidad (ver leyenda en el script).
- Hay dos modos en el menú:
  * TUTORIAL: siempre disponible.
  * JUGAR ARENA: se desbloquea al completar el tutorial al menos una vez
    (se guarda en user://progreso.cfg).
- El tutorial termina al tocar la meta de la arena; entonces se guarda el
  progreso y se muestra la pantalla de fin.
- TileSet embebido, atlas 1 fila (60 px, capa 4 pared) compuesto en runtime a
  partir de res://sprites/: suelo1.png, suelo2.png (variante) y t3.png (pared).
  La puerta usa el sprite nuevo res://sprites/door.png.
- El mundo procedural (GeneradorNivel) y sus tests están deprecados en
  `unused/` (con `unused/.gdignore`): no se importan ni se ejecutan.

5. GRUPOS / CAPAS DE FÍSICA (project.godot)
--------------------------------------------
  1 jugador | 2 dash | 3 enemigo | 4 pared | 5 daño | 6 colisión pared
  7 activar | 8 pinchos
- Puerta: collision_layer 8 (valor de capa 4, "pared"), bloquea al jugador.
- Pincho: Area2D en capa 8 ("pinchos"); el área `environment` del jugador
  la detecta y llama a golpear().

6. DASHES (movimiento y ataque = mismo gesto)
---------------------------------------------
Unidad de referencia: 1 tile = 60 px = 2 m.
- Dash fuerte (click izq, ataque, gasta 1 vial de sangre): 10 tiles = 600 px
- Dash normal (click der, solo movimiento): 5 tiles = 300 px
- Cada click = UN dash discreto (no hay movimiento continuo). El trayecto se
  interpola con un Tween (ease-out) y la física lo aplica con move_and_slide,
  así las paredes siguen bloqueando.
- Daño: SOLO el dash fuerte activa la hitbox de ataque. El normal NO daña.
- Feedback: estiramiento direccional al salir, partículas teñidas y sonido.
- Polling de dash corto: hasta 4 (COLA_MAX) clics derechos se encolan.

7. TUTORIAL, LLAVES Y PUERTAS
-----------------------------
- Seis salas en fila. Cada una enseña una acción y esconde la llave que abre
  su puerta este:
  1. Dash corto: moverse y recoger la llave.
  2. Dash fuerte: el guardia lleva la llave; al morir la suelta.
  3. Escudo: recogerlo y cruzar el pasillo de pinchos (sin escudo, mueres).
  4. Dash sombra (click central): atravesar el muro hasta la llave.
  5. Examen: escudo + pinchos + muro sombra + llave.
  6. Arena: enemigos, pinchos y meta.
- Las puertas NO se abren matando enemigos: se abren al tocarlas con una
  llave, que se consume. Sin llave, el HUD avisa.
- La puerta final se abre directamente si el tutorial ya se completó alguna
  vez; si no, exige la llave del examen.
- HUD: viales, llaves, escudo y dash sombra siempre visibles (atenuados a 0)
  con tooltip; panel de lección con icono de ratón; mensajes puntuales.
- Persistencia mínima: scripts/progreso.gd (user://progreso.cfg).

8. LUZ
------
- Antorchas con PointLight2D aditivo de baja energía (light_suave.png),
  separadas para que no se solapen; torch.gd anima energía y radio con dos
  senos desfasados. No usar Mix con esta textura: dibuja cajas negras.
- Los enemigos llevan un brillo rojo tenue (energía 0.35) para no sumar.
- CanvasModulate tenue en el nivel para que las antorchas se lean.
- El jugador no tiene luz propia: el dash se lee por sus partículas.

9. TESTS
--------
Uso: godot --headless --fixed-fps 60 --script res://tests/assert_XXX.gd
- assert_tutorial: 6 salas, llaves, puerta sin/con llave, tooltips, Mix.
- assert_dash / assert_cola_dash / assert_dash_dano: dashes y hitbox.
- assert_caza / assert_vision / assert_cobarde: enemigos.
- Varios tests antiguos de generación viven en unused/tests.
