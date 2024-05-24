module main

import json
import net
import crypto.rand
import lib
import utils

fn send_request(mut conn net.TcpConn, message utils.Request) bool {
	// send request
	msg := json.encode(message)
	conn.write(msg.bytes()) or {
		eprintln(err.msg())
		return false
	}
	println('sending ${message.typ} request to server...')

	// wait for ACK
	mut buff := []u8{len: int(lib.ByteSize.megabytes)}
	n := conn.read(mut buff) or {
		eprintln(err.msg())
		return false
	}
	buff.trim(n)

	response := json.decode(utils.Response, buff.bytestr()) or {
		eprintln(err.msg())
		return false
	}
	return response.ack
}

fn main() {
	// connect to server
	server_addr := '0.0.0.0:8080'
	mut conn := net.dial_tcp(server_addr)!
	defer {
		conn.close() or {
			eprintln('failed to close server connection ${err}')
			exit(1)
		}
	}

	fpath := 'test_data/file.txt'
	chunks := lib.chunk_file(fpath)!

	// send chunk upload request
	mut chunk := chunks.first()
	request := utils.Request{
		id: rand.bytes(16)!.hex()
		typ: utils.RequestType.upload
		payload: json.encode(chunk)
	}

	ok := send_request(mut conn, request)
	if !ok {
		eprintln('chunk upload request denied by server!')
		exit(1)
	}

	println('chunk upload request accepted by server')
}
