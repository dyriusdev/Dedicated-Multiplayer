const WebSocket = require('ws')
// Listener port
const PORT = 3000

// Server WebSocket
const SERVER = new WebSocket.Server({port : PORT})

console.log(`WebSocket Server starting at port : ${PORT}`)

// Object to store the state of connected clients
const clients = {}
let nextId = 1


// Event called when client connect
SERVER.on('connection', (ws) => {
	const clientId = `client_${nextId++}`
	clients[clientId] = {
		id : clientId,
		ws : ws,
		position : {x : 0, y : 0}
	}
	ws.clientId = clientId

	console.log(`Client with id ${clientId} connected!`)

	// Send the id to the new client
	ws.send(JSON.stringify({type : 'id_assigned', id : clientId}))

	// Send initial state of all clients
	const initialState = Object.values(clients).map(c => ({
		id : c.id,
		position : c.position
	}))
	ws.send(JSON.stringify({type : 'initial_state', states : initialState}))

	// Event called when an client send a message
	ws.on('message', (message) => {
		const received = message.toString()
		let parsed
		try {
			parsed = JSON.parse(received)
		} catch (e) {
			console.error('Json message invalid', e)
			return
		}

		console.log(`Message received from ${ws.clientId}`)

		switch (parsed.type) {
			case 'position_update':
				if (clients[ws.clientId]) {
					clients[ws.clientId] = parsed.position
                    SERVER.clients.forEach(c=> {
                        if (c.readyState === WebSocket.OPEN) {
                            c.send(JSON.stringify({
                                type : "move_update",
                                id : ws.clientId,
                                position : parsed.position                    
                            }))                        
                        }
                    })
				}
				break
			case 'chat_message':
				const sender = clients[ws.clientId]
				if (!sender) {
					console.warn(`Message from unknown client : ${ws.clientId}`)
					return
				}

				const chatMsg = parsed.message
				SERVER.clients.forEach(c => {
					const recipient = clients[c.clientId]
					if (recipient && c.readyState === WebSocket.OPEN) {
						c.send(JSON.stringify({
							type : 'chat_message_received',
							sender : sender.id,
							message : chatMsg
						}))
					}
				})
				console.log(`Message from client ${sender.id} "${chatMsg}" streamed to all clients`)
				break
			default:
				console.warn(`Type message unknow : ${parsed.type}`)
		}
	})

	// Event called when client close connection
	ws.on('close', () => {
		if (ws.clientId && clients[ws.clientId]) {
			console.log(`Client ${ws.clientId} disconnected`)
			delete clients[ws.clientId]
			// Notify all clients that an client is disconnected
			SERVER.clients.forEach(c => {
				if (c.readyState === WebSocket.OPEN) {
					c.send(JSON.stringify({
						type : 'disconnected',
						id : ws.clientId
					}))
				}
			})
		} else {
			console.log('Unknow client disconnected (id not found)')
		}
	})

	// Event called when an error ocurred
	ws.on('error', (error) => {
		console.error('WebSocket error :', error)
	})
})
