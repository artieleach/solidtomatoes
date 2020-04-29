extends ColorRect

enum {SPIRAL, CIRCLE, VECTOR, POWER_UP, FACTORY, SHUFFLE, FLOOD, EXPLODE}

export (PackedScene) var Card

var symbol_colors = [
	Color('000088'),   # blue
	Color('003c00'),   # green
	Color('880000'),   # red
	Color('480078'),   # purple
	Color('404040'),   # grey
	]

var card_size = Vector2(32, 43)
var table_size = Vector2(5, 5)
var card_offset = Vector2(0, 0)
var card_positions = []
var deck = []
var deck_copy = []
var cur_turn = 0
var turn_counter = 0
var mouse_pos = Vector2(0, 0)
var held_card
var current_neighbors = []
var deck_string = '02020303041212131314121213131422222323242222232324464646'.bigrams()
var possible_neighbors = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
var potential_card

var debug = true
var draw_size = 12

class NeighborSorter:
	static func sort(a, b):
		if a[1] < b[1]:
			return true
		return false

func lp(card):
	return '%s%s' % [card.symbol, str(clamp(card.value, 0, 9))]

func _ready():
	for card in range(len(deck_string)):
		if card % 2 == 0:
			deck.append(deck_string[card])
			deck_copy.append(deck_string[card])
	randomize()
	deck.shuffle()
	for x in range(table_size.x):
		card_positions.append([])
# warning-ignore:unused_variable
		for y in range(table_size.y):
			card_positions[x].append([])
	load_game()
	draw_from_deck(25)
	calculate_possible_moves()

func _process(_delta):
	update()
	if held_card:
		held_card.position = get_local_mouse_position() - card_offset
		var held_card_hover_position = Vector2(
			clamp(int((held_card.position.x + card_size.x / 2) / card_size.x), 0, table_size.x - 1),
			clamp(int((held_card.position.y + card_size.y / 2) / card_size.y), 0, table_size.y - 1))
		$highlight.visible = held_card.table_position != held_card_hover_position and held_card_hover_position in held_card.possible_moves
		$highlight.position = held_card_hover_position * card_size
		$shadow.position = held_card.position
	else:
		$highlight.visible = [card_positions[mouse_pos.x][mouse_pos.y]] != [[]] and card_positions[mouse_pos.x][mouse_pos.y].symbol != FACTORY
		$highlight.position = mouse_pos * card_size

func _draw():
	if debug:
		for i in range(len(card_positions)):
			for j in range(len(card_positions[i])):
				if card_positions[i][j]:
					draw_rect(Rect2(
						Vector2((i*draw_size)+64, (j*draw_size)+240), 
						Vector2(draw_size, draw_size)), 
						symbol_colors[card_positions[i][j].symbol] * (card_positions[i][j].value / 1.5))
				else:
					draw_rect(Rect2(Vector2((i*draw_size)+64, (j*draw_size)+240), Vector2(draw_size, draw_size)), Color(0, 0, 0))

func save_game():
	var output = ['']
	for i in range(len(card_positions)):
		for j in range(len(card_positions[i])):
			if card_positions[i][j]: 
				output[0] += lp(card_positions[i][j])
			else:
				output[0] += '00'
	for card in deck:
		output[0] += card
	output.append(str(cur_turn))
	var save_file = File.new()
	save_file.open("user://savegame.save", File.WRITE)
	for i in output:
		save_file.store_line(i)
	save_file.close()

func load_game():
	var f = File.new()
	if not f.file_exists("user://savegame.save"):
		draw_from_deck(table_size.x * table_size.y)
		save_game()
		return
	var loaded_data = []
	f.open("user://savegame.save", File.READ)
	loaded_data.append(f.get_line().bigrams())
	for _i in range(3):
		loaded_data.append(f.get_line())
	f.close()
	deck = []
	for card in range(len(loaded_data[0])):
		if card % 2 == 0:
			deck.append(loaded_data[0][card])
	draw_from_deck(len(deck))
	cur_turn = int(loaded_data[1])
	turn_counter = int(loaded_data[1])

func make_card(symbol, value, table_position):
	var new_card = Card.instance()
	add_child(new_card)
	new_card.value = value
	new_card.symbol = symbol
	new_card.table_position = table_position
	new_card.last_position = table_position
	new_card.card_path = str(get_path_to(new_card)) + '/'
	new_card.turn_created = turn_counter
	new_card.pickable = symbol != FACTORY
	get_node(new_card.card_path).frame = randi() % 5
	update_card(new_card)
	card_positions[new_card.table_position.x][new_card.table_position.y] = new_card
	return new_card

func draw_from_deck(num_to_draw, delay := 0):
	var total_to_draw = num_to_draw + delay
	var skipped = 0
	for x in range(table_size.x):
		for y in range(table_size.y):
			if not card_positions[x][y]:
				if num_to_draw > 0:
					if deck:
						var new_card = null
						num_to_draw -= 1
						if int(deck[0][1]) > 0:
							new_card = make_card(int(deck[0][0]), int(deck[0][1]), Vector2(x, y))
							new_card.position = Vector2(0, 224)
							get_in_place(new_card, 0.1 * ((total_to_draw - num_to_draw) - skipped))
							$Tween.interpolate_property(new_card, "z_index", num_to_draw*10, new_card.table_position.y, 0.3, Tween.TRANS_LINEAR, Tween.EASE_OUT, 0.1 * ((total_to_draw - num_to_draw) - skipped))
							$Tween.start()
						else:
							skipped += 1 
						deck.pop_front()
					else:
						deck = deck_copy.duplicate(true)
						deck.shuffle()
						draw_from_deck(num_to_draw, total_to_draw-num_to_draw)
			else:
				update_card(card_positions[x][y])
	num_to_draw = 0

func calculate_possible_moves():
	for row in card_positions:
		for card in row:
			if card:
				update_card(card)
				var cur_neighborhood = get_neighbors(card)
				card.possible_moves = []
				for neighbor in cur_neighborhood[1]:
					var cur_n_symbol = neighbor[1].symbol
					match card.symbol:
						cur_n_symbol:
							card.possible_moves.append(neighbor[1].table_position)
						SPIRAL:
							card.possible_moves.append(neighbor[1].table_position)
						CIRCLE:
							if neighbor[1].symbol != FACTORY:
								card.possible_moves.append(neighbor[1].table_position)
						VECTOR:
							if neighbor[1].value < card.value and neighbor[1].symbol != FACTORY:
								card.possible_moves.append(neighbor[1].table_position)
						POWER_UP:
							if neighbor[1].symbol != FACTORY:
								card.possible_moves.append(neighbor[1].table_position)
						SHUFFLE:
							card.possible_moves.append(neighbor[1].table_position)
						FLOOD:
							if neighbor[1].symbol == SPIRAL:
								card.possible_moves.append(neighbor[1].table_position)
						EXPLODE:
							card.possible_moves.append(neighbor[1].table_position)

func get_neighbors(card, spot:=Vector2(0, 0)) -> Array:
	if spot == Vector2(0, 0):
		spot = card.table_position
	var neighbors = []
	var living_neighbors = []
	for poss_n in possible_neighbors:
		if 0 <= spot.x + poss_n.x and spot.x + poss_n.x < table_size.x and 0 <= spot.y + poss_n.y and spot.y + poss_n.y < table_size.y:
			neighbors.append([Vector2(spot.x + poss_n.x, spot.y + poss_n.y), card_positions[spot.x + poss_n.x][spot.y + poss_n.y]])
			if neighbors[-1][1]:
				living_neighbors.append(neighbors[-1])
	return [neighbors, living_neighbors]

func update_card(card):
	card.z_index = card.table_position.y
	update_table(card)
	var diff = abs(get_node(card.card_path + "Value").frame - card.value)
	if diff != 0:
		$Tween.interpolate_property(get_node(card.card_path + "Value"), "frame", get_node(card.card_path + "Value").frame, card.value, 0.05 * diff)
		$Tween.start()
	get_node(card.card_path + "Value").frame = card.value
	get_node(card.card_path + "Symbol").frame = card.symbol
	get_node(card.card_path + "Value").modulate = symbol_colors[card.symbol]
	get_node(card.card_path + "Clock").visible = card.symbol == FACTORY

func grab_card(card):
	save_game()
	calculate_possible_moves()
	if card.symbol != FACTORY and card.pickable:
		$Tween.interpolate_property(card, "offset", card.offset, Vector2(-1, -6), 0.15, Tween.TRANS_CIRC, Tween.EASE_OUT)
		$Tween.interpolate_property(card, "scale", card.scale, Vector2(1.05, 1.05), 0.2, Tween.TRANS_LINEAR)
		current_neighbors = get_neighbors(card)[1]
		for neighbor in current_neighbors:
			if neighbor[1].table_position in card.possible_moves:
				$Tween.interpolate_property(neighbor[1], "self_modulate", neighbor[1].self_modulate, Color(1.2, 1.2, 1.2), 0.1, Tween.TRANS_QUART, Tween.EASE_OUT)
				$Tween.start()
		card_positions[card.table_position.x][card.table_position.y] = []
		card.z_index = 100
		held_card = card

func drop_card(card):
	$highlight.visible = true
	$shadow.visible = false
	var turn_is_valid = false
	$Tween.interpolate_property(card, "offset", card.offset, Vector2(0, 0), 0.15, Tween.TRANS_CIRC, Tween.EASE_OUT)
	$Tween.interpolate_property(card, "scale", card.scale, Vector2(1, 1), 0.2, Tween.TRANS_LINEAR)
	if held_card and held_card == card:
		current_neighbors = get_neighbors(held_card, held_card.last_position)[1]
		for neighbor in current_neighbors:
			$Tween.interpolate_property(neighbor[1], "self_modulate", neighbor[1].self_modulate, Color(1, 1, 1), 0.1, Tween.TRANS_QUART, Tween.EASE_OUT)
			$Tween.start()
			neighbor[1].self_modulate = 0
		held_card.table_position = Vector2(
			clamp(int((held_card.position.x + card_size.x / 2) / card_size.x), 0, table_size.x - 1), 
			clamp(int((held_card.position.y + card_size.y / 2) / card_size.y), 0, table_size.y - 1))
		var targeted_card = card_positions[held_card.table_position.x][held_card.table_position.y]
		if targeted_card:
			if targeted_card.table_position in held_card.possible_moves:
				if held_card.symbol < FACTORY:
					turn_is_valid = card_take_turn(held_card, targeted_card)
				else:
					turn_is_valid = power_up_take_turn(targeted_card)
			else:
				held_card.table_position = held_card.last_position
		elif held_card.table_position != held_card.last_position:
			if held_card.table_position.distance_to(held_card.last_position) == 1:
				turn_is_valid = true
			else:
				held_card.table_position = held_card.last_position
		else:
			held_card.table_position = held_card.last_position
		update_card(held_card)
		held_card = null
		get_in_place(card)
		if turn_is_valid:
			turn_counter += 1
		if turn_counter != cur_turn:
			cur_turn = turn_counter
			for row in card_positions:
				for card in row:
					if card and card.symbol == FACTORY:
						get_node(card.card_path + "Clock").frame = (turn_counter+card.turn_created) % 3
						if true: # turn_counter > (card.turn_created + 1) and (turn_counter + card.turn_created) % 3 == 0:
							pass
							#factory_take_turn(card)

func factory_take_turn(card):
	var factory_neighbors = get_neighbors(card)[0]
	var neighbor_score = factory_neighbors.duplicate(true)
	for item in neighbor_score:
		item[1] = 0
	for neighbor in factory_neighbors:
		if neighbor[1] and neighbor[1].symbol == VECTOR:
			for item in neighbor_score:
				if item[0] == neighbor[0]:
					item[1] += 1
	neighbor_score.sort_custom(NeighborSorter, "sort")
	for neighbor in factory_neighbors:
		if neighbor[0] == neighbor_score[0][0]:
			if neighbor[1]:
				switch_card_positions(card, neighbor[1])
				print('switch, neighbor')
				return
			else:
				print('switch, no neighbor')
				card_positions[card.table_position.x][card.table_position.y] = []
				card.table_position = neighbor_score[0][0]
				update_card(card)
				get_in_place(card)
				return

func switch_card_positions(card_a, card_b):
	var old_table_pos = card_a.table_position
	card_a.table_position = card_b.table_position
	card_b.table_position = old_table_pos
	update_card(card_a)
	update_card(card_b)
	get_in_place(card_b)

func get_in_place(card, delay:=0.0):
	$Tween.interpolate_property(card, "position", card.position, card.table_position * card_size, 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT, delay)
	$Tween.start()

func card_take_turn(card, target):
	card.table_position = card.last_position
	match card.symbol:
		target.symbol:
			target.value = min(9, card.value + target.value)
			card.table_position = target.table_position
			card.value = 0
			update_card(card)
			target_take_turn(target)
			return true
		SPIRAL:
			if target.symbol in [CIRCLE, VECTOR]:
				target.symbol = [0, 2, 1][target.symbol]
			switch_card_positions(card, target)
			card.value -= 1
			return true
		CIRCLE:
			target.value = min(9, card.value + target.value)
			update_card(target)
			card.value = 0
			card.table_position = target.table_position
			update_card(card)
			return true
		VECTOR:
			var holder = card.value
			card.value -= target.value
			target.value = target.value - holder
			switch_card_positions(card, target)
			return true
		POWER_UP:
			power_up_take_turn(target)
			update_card(target)
			card.value = 0
			return true
	update_card('turn failed, impossible move')
	return false

func power_up_take_turn(card):
	var card_arr = card_positions.duplicate(true)
	var power_up_value = card.value
	card.value = 0
	update_table(card)
	match card.symbol:
		CIRCLE:
			var possible_spots = []
			for x in range(table_size.x):
				for y in range(table_size.y):
					possible_spots.append(Vector2(x, y))
					card_positions[x][y] = []
			possible_spots.shuffle()
			for row in card_arr:
				for card in row:
					if card and card != self:
						card.table_position = possible_spots[0]
						get_in_place(card)
						update_card(card)
						possible_spots.pop_front()
			draw_from_deck(power_up_value)
			return true
		SPIRAL:
			for row in card_positions:
				for card in row:
					if card and card.symbol == SPIRAL:
						var spi_neighbors = get_neighbors(card)[0]
						for spot in spi_neighbors:
							if not spot[1]:
								make_card(power_up_value, SPIRAL, spot[0]) 
								break
			return true
		VECTOR:
			for row in card_arr:
				for card in row:
					if card and card.symbol == VECTOR:
						card.value = power_up_value
						target_take_turn(card)
	return false

func target_take_turn(card):
	var living_neighbors = get_neighbors(card)[1]
	var living_val = card.value
	card.value = 0
	match card.symbol:
		CIRCLE:
			update_card(card)
			draw_from_deck(living_val)
		SPIRAL:
			for neighbor in living_neighbors:
				if neighbor[1].symbol in [CIRCLE, VECTOR]:
					neighbor[1].symbol = [0, 2, 1][neighbor[1].symbol]
				update_card(neighbor[1])
			card.symbol = POWER_UP
			card.value = 1
			update_card(card)
		VECTOR:
			for neighbor in living_neighbors:
				neighbor[1].value -= living_val
				update_card(neighbor[1])
	update_card(card)

func update_table(card):
	if card.value > 0:
		card_positions[card.table_position.x][card.table_position.y] = card
		card.last_position = card.table_position
	else:
		card_death(card)

func card_death(card):
	card.add_to_group('dying_cards')
	if card in [card_positions[card.table_position.x][card.table_position.y]]:
		card_positions[card.table_position.x][card.table_position.y] = []
	if card in current_neighbors:
		current_neighbors.remove(current_neighbors.find(card))
	card.pickable = false
	var diff = abs(get_node(card.card_path + "Value").frame - card.value)
	$Tween.interpolate_property(get_node(card.card_path + "Value"), "frame", get_node(card.card_path + "Value").frame, card.value, 0.05 * diff)
	$Tween.start()
	$Tween.interpolate_callback(card, 0.05 * (diff + 0.5), "queue_free")

func _on_table_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			var mouse_table = Vector2(int(event.position.x) / int(card_size.x) , int(event.position.y) / int(card_size.y))
			if mouse_table.x < table_size.x and mouse_table.y < table_size.y:
				potential_card = card_positions[mouse_table.x][mouse_table.y]
				if event.pressed and potential_card and potential_card.symbol != FACTORY:
					if potential_card:
						card_offset = Vector2(int(round(event.position.x)) % int(card_size.x), int(round(event.position.y)) % int(card_size.y))
						grab_card(potential_card)
				else:
					if held_card:
						drop_card(held_card)
			else:
				for row in card_positions:
					for card in row:
						if card:
							card.value = 0
							update_card(card)
				draw_from_deck(25)
	elif event is InputEventMouseMotion:
		mouse_pos = Vector2(
			clamp(int((int(event.position.x)) / card_size.x), 0, table_size.x - 1),
			clamp(int((int(event.position.y)) / card_size.y), 0, table_size.y - 1))

func _on_Tween_tween_completed(object, key):
	if object.is_in_group('dying_cards'):
		print('here', object, key)
		object.queue_free()