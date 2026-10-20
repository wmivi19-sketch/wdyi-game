extends RigidBody2D
## Cosmetic 2D ballistic debris: it must never collide with the actor or another floor.
var landing_y: float = 0.0
var landed: bool = false
var ground_age: float = 0.0
var source_height: float = 0.0
var world

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
    if landed: return
    state.linear_velocity.y += 600.0*state.step
    if state.linear_velocity.y>0 and state.transform.origin.y>=landing_y:
        var pose := state.transform
        pose.origin.y = landing_y
        state.transform = pose
        state.linear_velocity = Vector2.ZERO
        state.angular_velocity = 0.0
        landed = true
        set_deferred("freeze",true)

func _physics_process(delta: float) -> void:
    visible = absf(world.player.current_z_height-source_height)<38.0
    if not landed: return
    ground_age += delta
    modulate.a = 1.0-smoothstep(1.6,2.0,ground_age)
    if ground_age>=2.0: queue_free()
