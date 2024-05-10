module lib

import os
import crypto.md5

pub struct DfSfile {
pub:
	filename      string   @[required]
	chunks        []Chunk  @[required]
	chunk_servers []string = []string{}
}

pub struct Chunk {
pub:
	cur_pos u64
	bufsize u64
pub mut:
	fpath  string
	md5sum string
}

pub fn (mut c Chunk) get_data() ![]u8 {
	mut file := os.open_file(c.fpath, 'rb', 0o666)!
	defer {
		file.close()
	}

	fsize := os.file_size(c.fpath)
	buffer := file.read_bytes(int(fsize))
	println('reading ochunk ${buffer.len} bytes from file ${c.fpath}...')

	return buffer
}

// partitions large files into small chunks,
// saves each chunk to disk as a file and returns a DfSfile struct
pub fn chunk_file(fpath string) !DfSfile {
	mut file := os.open_file(fpath, 'rb', 0o666)!
	defer {
		file.close()
	}

	fsize := os.file_size(fpath)
	if fsize == 0 {
		return error('cannot chunk empty file')
	}

	chunk_size := 69 * u32(FileSize.megabytes)
	mut chunks := []Chunk{}
	mut cur_pos := u64(0)
	mut threads := []thread !Chunk{}

	for !file.eof() {
		buffer := file.read_bytes_at(chunk_size, cur_pos)
		println('chunking ${buffer.len} bytes of data...')

		parent_fpath := fpath
		current_curpos := cur_pos
		threads << spawn save_chunk_to_disk(parent_fpath, current_curpos, buffer)

		cur_pos += u64(buffer.len)
	}

	for _, t in threads {
		// TODO: when goroutine fails to save chunk to disk return failed chunk for retry
		chunk := t.wait() or { return error('failed to save chunk to disk: ${err}') }
		chunks << chunk
	}

	return DfSfile{
		filename: fpath
		chunks: chunks
	}
}

fn save_chunk_to_disk(parent_fpath string, cur_pos u64, buffer []u8) !Chunk {
	// generate chunk file path
	md5sum := md5.sum(buffer).hex()[..20]
	mut fname := os.base(parent_fpath)
	fname = '${md5sum}_${cur_pos}_${fname}'
	fpath := os.join_path(os.dir(parent_fpath), fname)

	if os.is_file(fpath) {
		println('file ${fname} already exists...')
	} else {
		mut file := os.open_file(fpath, 'wb', 0o666)!
		defer {
			file.close()
		}

		n := file.write_to(cur_pos, buffer)!
		println('writing ${n} bytes to file ${fname}...')
	}

	return Chunk{
		cur_pos: cur_pos
		fpath: fpath
		md5sum: md5sum
		bufsize: u64(buffer.len)
	}
}
