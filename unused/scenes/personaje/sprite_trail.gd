extends Node
## Afterimage trail for the strong dash (Celeste / Hades style).
## Stability-first: ghosts are plain AnimatedSprite2D with a single
## fade tween each; capped per frame, nulled safely, never blocks gameplay.

@onready var animated_sprite: AnimatedSprite2D = $"../AnimatedSprite2D"
@export var trail_container: Node

@export_group("Dash Trail")
@export var ghost_interval: float = 0.03 ## seconds between afterimages (lower = denser)
@export var ghost_fade_time: float = 0.3 ## how fast each ghost fades
@export var ghost_alpha: float = 0.55 ## starting opacity
@export var ghost_tint: Color = Color(1.0,1,1, 1.0) ## blood-tinted, matches HUD

# Legacy: el jugador ya no usa fantasmas (la luz local del dash los sustituye).
var _trail_active: bool = false
var _cooldown: float = 0.0

func _ready():
	if trail_container == null:
		# get_tree() can be null in editor previews; fall back to parent.
		var tree := get_tree()
		if tree != null and tree.current_scene != null:
			trail_container = tree.current_scene
		else:
			trail_container = get_parent()

## Called by the player when a strong dash starts. Safe to call twice.
func start_trail() -> void:
	_trail_active = true
	_cooldown = 0.0
	_spawn_ghost() # immediate ghost on frame 1, like Celeste (no 1-frame gap)

## Called by the player when the dash ends. Lets existing ghosts fade out.
func stop_trail() -> void:
	_trail_active = false

func _physics_process(delta):
	if not _trail_active:
		return
	if animated_sprite == null or trail_container == null:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = maxf(ghost_interval, 0.01)
		_spawn_ghost()

func _spawn_ghost():
	# Alias kept for backwards compatibility (old code called crear_ghost).
	crear_ghost()

func crear_ghost():
	if animated_sprite == null or trail_container == null:
		return
	if animated_sprite.sprite_frames == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var ghost := AnimatedSprite2D.new()
	# Frozen snapshot (no play): static afterimage like Celeste/Hades,
	# cheaper and avoids noisy desynced animations.
	ghost.sprite_frames = animated_sprite.sprite_frames
	ghost.animation = animated_sprite.animation
	ghost.frame = animated_sprite.frame
	
	ghost.top_level = true
	trail_container.add_child(ghost)
	ghost.global_transform = animated_sprite.global_transform
	ghost.flip_h = animated_sprite.flip_h
	ghost.flip_v = animated_sprite.flip_v
	ghost.offset = animated_sprite.offset
	
	# Blood-tinted afterimage, behind the player. Already top-level so it
	# stays in the world while the player moves away (real "trail" effect).
	ghost.modulate = Color(ghost_tint.r, ghost_tint.g, ghost_tint.b, ghost_alpha)
	ghost.z_index = -1
	
	# Single fade-out tween, then free. Bound to ghost so a scene change
	# can't leave a dangling tween (stability).
	var tween := tree.create_tween()
	tween.set_parallel(false)
	tween.bind_node(ghost)
	tween.tween_property(ghost, "modulate:a", 0.0, maxf(ghost_fade_time, 0.05))
	tween.tween_callback(ghost.queue_free)
