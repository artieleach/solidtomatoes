extends AnimatedSprite

var symbol
var value
var table_position
var card_path
var possible_moves
var last_position
var turn_created
var pickable


func _process(_delta):
	$Value.offset = offset
	$Symbol.offset = offset
	if $Symbol.frame == 5:
		$Symbol.playing = false
		$Symbol.frame = 0
	
func thump_particles(z := 0, dying := false):
	$Particles2D.z_index = -1
	if dying:
		$Particles2D.z_index = 100
	$Particles2D.emitting = true
