module main

import json
import os
import net
import net.mbedtls
import crypto.md5
import lib
import utils

fn send_response(mut conn mbedtls.SSLConn, response utils.Response) ! {
	data := json.encode(response).bytes()
	conn.write(data) or { conn.shutdown() or { return err } }

	if !response.ack {
		return error('denied clients ${response.request_typ} request[${response.id}]')
	}
	
	println('accepted clients ${response.request_typ} request[${response.id}]')
}

fn read_buffer(mut conn mbedtls.SSLConn, buffer_size u64) ![]u8 {
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

fn handle_upload_request(mut conn mbedtls.SSLConn, request utils.Request) ! {
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
	buffer := read_buffer(mut conn, chunk.bufsize)!

	// save chunk to disk
	chunk.save_data(buffer) or {
		return error('failed to save chunk ${chunk.md5sum} to disk! ${err.msg()}')
	}
}

fn handle_client(mut conn mbedtls.SSLConn) {
	peer_addr := conn.peer_addr() or {
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
	ca_cert := utils.parse_filepath("~/certs/ca-cert.pem")
	server_cert := os.abs_path('certs/server/server.crt')
	server_key := os.abs_path('certs/server/server.key')

	mut server := mbedtls.new_ssl_listener(server_addr, mbedtls.SSLConnectConfig{
        verify: ca_cert
        cert: server_cert
        cert_key: server_key
        validate: true // mTLS
    })!
	// mut server := net.listen_tcp(net.AddrFamily.ip, server_addr)!
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
