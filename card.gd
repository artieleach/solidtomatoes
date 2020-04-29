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
	
