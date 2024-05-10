module main

import net
import net.websocket

fn handle_client_msg(mut c websocket.Client, msg &websocket.Message) ! {
	println('received message ${msg} from client ${c.id}...')

	// parse message
	payload := msg.payload.bytestr()
	println('client ${c.id} says ${payload}')
}

fn on_client_connect(mut c websocket.ServerClient) !bool {
	println('client connected to server...')
	return true
}

fn main() {
	// start server
	mut server := websocket.new_server(net.AddrFamily.ip, 8080, '127.0.0.1', websocket.ServerOpt{})
	server.on_connect(on_client_connect) or { panic(err) }

	server.on_message(handle_client_msg)
	server.listen() or { panic(err) }
}
