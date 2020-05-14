extends AnimatedSprite

var symbol
var value
var table_position
var card_path
var possible_moves
var last_position
var turn_created
var pickable
var can_shine = true


func _process(_delta):
	$Value.offset = offset
	$Symbol.offset = offset
	
func thump_particles(z := 0):
	$Particles2D.z_index = z
	$Particles2D.emitting = true

func _on_Symbol_animation_finished():
	$Symbol.frame = 0
	$Symbol.playing = false
	can_shine = false
	$Timer.start()


func _on_Timer_timeout():
	can_shine = true
