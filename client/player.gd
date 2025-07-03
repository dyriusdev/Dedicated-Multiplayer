extends CharacterBody2D

@onready var position_update_timer : Timer = $PositionUpdateTimer
@onready var messages : RichTextLabel = $Chat/Container/Messages
@onready var enter : LineEdit = $Chat/Container/Enter

var socket : WebSocketPeer = WebSocketPeer.new()
var url : String = "ws://localhost:3000"
var player_id : String = ""

const SPEED = 100

func _ready() -> void:
	var error : Error = socket.connect_to_url(url)
	if error != OK:
		print("Error trying to connect", error)
		messages.append_text("[color=red]Connection error![/color]\n")
	pass

func _process(_delta : float) -> void:
	socket.poll()
	var state : int = socket.get_ready_state()
	match state:
		WebSocketPeer.STATE_CONNECTING:
			messages.append_text("[color=yellow]Connecting to the server...[/color]\n")
		WebSocketPeer.STATE_OPEN:
			while socket.get_available_packet_count():
				process_packet(socket.get_packet())
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CLOSED:
			var code = socket.get_close_code()
			var reason = socket.get_close_reason()
			print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
			messages.append_text("[color=red]Connection error![/color]\n")
			set_process(false)
	pass

func _physics_process(_delta : float) -> void:
	var input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input * SPEED
	move_and_slide()
	pass

func process_packet(packet : PackedByteArray) -> void:
	var data : String = packet.get_string_from_utf8()
	var parsed : Dictionary = JSON.parse_string(data)
	
	if not parsed:
		print("Error parsing json :", data)
		return
	
	print("Packet type :", parsed.type)
	match parsed.type:
		"id_assigned":
			player_id = parsed.id
			print("Player id received from server ", player_id)
			messages.append_text("[color=green]Id : %s - connected![/color]\n" % player_id)
		"initial_state":
			print("Initial state received :", parsed.states)
		"move_update":
			print("Update position :", parsed)
		"chat_message_received":
			var message : String = parsed.message
			print("Received message :", message)
			messages.append_text("[color=white]%s[/color]\n" % message)
		"disconnected":
			print("Player disconnected ", parsed.id)
			messages.append_text("[color=red]Id : %s - diconnected![/color]\n" % parsed.id)
	pass

func _notification(what : int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close()
		print("Disconnected from server")
	pass

func send_json(data : Dictionary) -> void:
	var json : String = JSON.stringify(data)
	var error : Error = socket.send_text(json)
	if error != OK:
		print("Error sending json :", json)
	pass

func _on_position_update_timer_timeout() -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN and player_id:
		var position_data : Dictionary = {
			"type" : "position_update",
			"id" : player_id,
			"position" : {
				"x" : global_position.x,
				"y" : global_position.y 
			}
		}
		send_json(position_data)
	pass

func _on_enter_text_submitted(new_text: String) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN and player_id:
		var chat_data : Dictionary = {
			"type" : "chat_message",
			"sender" : player_id,
			"message" : new_text
		}
		send_json(chat_data)
		enter.clear()
	pass
