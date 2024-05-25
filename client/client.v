module main

import json
import net
import os
import time
import crypto.md5
import crypto.rand
import lib
import utils

fn send_request(mut conn net.TcpConn, request utils.Request) ! {
	// send request
	msg := json.encode(request)
	conn.write(msg.bytes())!
	println('sent ${request.typ} request[${request.id}] to server...')

	// wait for ACK
	mut buff := []u8{len: int(lib.ByteSize.kilobytes)}
	n := conn.read(mut buff)!
	buff.trim(n)

	response := json.decode(utils.Response, buff.bytestr())!
	if !response.ack {
		return error('${request.typ} request[${request.id}] denied by server')
	}

	println('${request.typ} request[${request.id}] accepted by server')
}

fn send_buffer(mut conn net.TcpConn, buffer []u8) !int {
	buffsize := 100 * int(lib.ByteSize.kilobytes)
	mut bytes_sent := 0

	for bytes_sent < buffer.len {
		mut buff := []u8{}

		mut slice_end := bytes_sent + buffsize
		slice_end = match true {
			slice_end > buffer.len {
				buffer.len
			}
			else {
				slice_end
			}
		}

		payload := buffer[bytes_sent..slice_end]
		buff << payload

		// println("sending ${buff.len} B of data")
		n := conn.write(buff)!
		bytes_sent += n
	}

	time.sleep(2 * time.second)

	hash := md5.sum(buffer).hex()
	println('sent ${bytes_sent} B of data\t${hash}')
	return bytes_sent
}

fn upload_file(server_addr string, fpath string) ! {
	mut chunks := lib.chunk_file(fpath)!

	for mut chunk in chunks {
		// create new connection for every chunk upload
		mut conn := net.dial_tcp(server_addr)!
		defer {
			conn.close() or { err }
		}

		println('sending chunk ${chunk}')
		request := utils.Request{
			id: rand.int_u64(100) or { 0 }
			typ: utils.RequestType.upload
			payload: json.encode(chunk)
		}
		send_request(mut conn, request)!

		// send chunk data
		buffer := chunk.load_data()!
		send_buffer(mut conn, buffer)!
	}
}

fn main() {
	// connect to server
	server_addr := '0.0.0.0:8080'
	fpath := 'test_data/file.txt'

	stopwatch := time.new_stopwatch()

	upload_file(server_addr, fpath) or {
		eprintln(err.msg())
		exit(1)
	}

	elapsed := stopwatch.elapsed()

	fsize := os.file_size(fpath)
	println('took ${elapsed.seconds()} s to upload ${fsize / u64(lib.ByteSize.gigabytes)} GB file')
}
