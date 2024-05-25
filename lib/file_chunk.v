module lib

import os
import crypto.md5

pub struct Chunk {
pub:
	cur_pos u64 @[required]
	bufsize u64 @[required]
pub mut:
	fpath  string @[required]
	md5sum string
}

// we do not wish to store large sections of data in memory
// store data in storage instead and access it whenever needed
pub fn (mut c Chunk) load_data() ![]u8 {
	mut file := os.open_file(c.fpath, 'rb', 0o666)!
	defer {
		file.close()
	}

	fsize := os.file_size(c.fpath)
	buffer := file.read_bytes(int(fsize))
	
	hash := md5.sum(buffer).hex()
	println('loaded buffer from file ${c.md5sum}\t${hash}')
	return buffer
}

pub fn (mut c Chunk) save_data(buffer []u8) !Chunk {
	if os.is_file(c.fpath) {
		println('file ${c.md5sum} already exists')
	} else {
		mut file := os.open_file(c.fpath, 'wb', 0o666)!
		defer {
			file.close()
		}

		file.write_to(0, buffer)!
		println('saved data to file ${c.md5sum}')
	}
	return c
}

// partitions large files into small chunks,
// saves each chunk to disk as a file and returns an array of chunks
pub fn chunk_file(fpath string) ![]Chunk {
	mut file := os.open_file(fpath, 'rb', 0o666)!
	defer {
		file.close()
	}

	fsize := os.file_size(fpath)
	if fsize == 0 {
		return error('cannot chunk empty file')
	}

	chunk_size := 69 * u32(ByteSize.megabytes)
	mut chunks := []Chunk{}
	mut cur_pos := u64(0)
	mut threads := []thread !Chunk{}

	for !file.eof() {
		buffer := file.read_bytes_at(chunk_size, cur_pos)
		println('chunked ${buffer.len / int(ByteSize.megabytes)} MB of data')

		parent_fname := os.base(fpath)
		hash := md5.sum(buffer).hex()
		new_fname := '${hash}_${cur_pos}_${parent_fname}'
		new_fpath := os.join_path(os.dir(fpath), new_fname)

		mut chunk := &Chunk{
			cur_pos: cur_pos
			bufsize: u64(buffer.len)
			fpath: new_fpath
			md5sum: hash
		}
		threads << spawn chunk.save_data(buffer)
		cur_pos += u64(buffer.len)
	}

	for _, t in threads {
		// TODO: when goroutine fails to save chunk to disk return failed chunk for retry
		chunk := t.wait() or { return error('failed to save chunk to disk: ${err}') }
		chunks << chunk
	}

	return chunks.clone()
}
