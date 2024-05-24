module main

import json
import net
import lib
import utils

fn send_response(mut conn net.TcpConn, response utils.Response) {
	data := json.encode(response).bytes()
	conn.write(data) or { conn.close() or { panic(err) } }
	println('sent response ${response} to client')
}

fn handle_client(mut conn net.TcpConn) ! {
	peer_addr := conn.peer_ip()!
	println('new client connection at peer address ${peer_addr}...')

	// read clients request
	mut buff := []u8{len: int(lib.ByteSize.kilobytes)}
	n := conn.read(mut buff)!
	buff.trim(n)

	request := json.decode(utils.Request, buff.bytestr())!
	mut response := utils.Response{
		id: request.id
		ack: false
	}

	match request.typ {
		.upload {
			chunk := json.decode(lib.Chunk, request.payload) or {
				err_msg := 'incorrect formatting of chunk payload: ${err.msg()}'
				eprintln(err_msg)

				send_response(mut conn, response)
				panic(err_msg)
			}

			println('client wants to upload chunk ${chunk}')
			response.ack = true
			send_response(mut conn, response)
		}
		.download {
			println('downloading...')
		}
		.search {
			println('searching...')
		}
		else {}
	}
}

fn main() {
	// start server
	server_addr := '0.0.0.0:8080'
	mut server := net.listen_tcp(net.AddrFamily.ip, server_addr)!
	println('started server on address ${server_addr}')

	for {
		println('waiting for client connections...')
		mut conn := server.accept() or {
			eprintln('failed to establish client connection! ${err}')
			continue
		}

		handle_client(mut conn)!
	}

	panic('server shutting down!')
}
