module main

import json
import net
import crypto.md5
import lib
import utils

fn send_response(mut conn net.TcpConn, response utils.Response) ! {
	data := json.encode(response).bytes()
	conn.write(data) or { conn.close() or { return err } }

	if !response.ack {
		return error('denied clients ${response.request_typ} request[${response.id}]')
	}
	
	println('accepted clients ${response.request_typ} request[${response.id}]')
}

fn read_buffer(conn net.TcpConn, buffer_size u64) ![]u8 {
	mut buffer := []u8{}
	mut bytes_recv := 0
	println('expected buffer size: ${int(buffer_size)}')

	for bytes_recv < buffer_size {
		mut buff := []u8{len: 100 * int(lib.ByteSize.kilobytes)}
		n := conn.read(mut buff)!
		buff.trim(n)

		bytes_recv += n
		buffer << buff
	}

	hash := md5.sum(buffer).hex()
	println('received ${bytes_recv} B of data\t${hash}')
	return buffer
}

fn handle_upload_request(mut conn net.TcpConn, request utils.Request) ! {
	mut response := utils.Response{
		id: request.id
		request_typ: request.typ
		ack: false
	}

	mut chunk := json.decode(lib.Chunk, request.payload) or {
		err_msg := 'incorrect formatting of chunk payload: ${err.msg()}'
		eprintln(err_msg)

		send_response(mut conn, response)!
		return error(err_msg)
	}

	println('received client ${request.typ} request[${request.id}] for chunk ${chunk}')
	response.ack = true
	send_response(mut conn, response)!

	// receive uploaded chunk data
	buffer := read_buffer(conn, chunk.bufsize)!

	// save chunk to disk
	chunk.save_data(buffer) or {
		return error('failed to save chunk ${chunk.md5sum} to disk! ${err.msg()}')
	}
}

fn handle_client(mut conn net.TcpConn) {
	peer_addr := conn.peer_ip() or {
		eprintln(err.msg())
		return
	}
	println('new client connection at peer address ${peer_addr}...')

	// read clients request
	mut buff := []u8{len: int(lib.ByteSize.kilobytes)}
	n := conn.read(mut buff) or {
		eprintln(err.msg())
		return
	}
	buff.trim(n)

	request := json.decode(utils.Request, buff.bytestr()) or {
		eprintln(err.msg())
		return
	}

	match request.typ {
		.upload {
			handle_upload_request(mut conn, request) or {
				eprintln(err.msg())
				exit(1)
			}
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

		spawn handle_client(mut conn)
	}

	panic('server shutting down!')
}
