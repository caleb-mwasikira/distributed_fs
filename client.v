module main

import net.websocket

fn main() {
	// start client
	mut client := websocket.new_client('http://127.0.0.1:8080', websocket.ClientOpt{}) or {
		panic(err)
	}
	defer {
		client.close(1, 'goodbye :(') or { panic('${err.msg()}; failed to close connection') }
	}

	client.connect() or { panic(err) }
	client.write_string('hello world') or { panic(err) }
}
