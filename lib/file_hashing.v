module lib

import os
import crypto.sha256

pub enum FileSize as u32 {
	byte      = 8 // 1 byte -> 8 bits
	kilobytes = 1024 // 1 kb -> 1024 bytes
	megabytes = 1024 * 1024
	gigabytes = 1024 * 1024 * 1024
}

pub fn hash_file(fpath string) !string {
	mut file := os.open_file(fpath, 'rb', 700)!
	defer {
		file.close()
	}

	max_bufsize := 69 * int(FileSize.megabytes) // 60MB

	// if file size is small enough,
	// just load all the data into memory and compute the hash
	fsize := os.file_size(fpath)
	if fsize <= max_bufsize {
		buffer := file.read_bytes(int(fsize))
		return sha256.sum(buffer).hex()
	}

	mut cur_pos := u64(0)
	mut threads := []thread{}
	shared hashes := map[u64][]u8{}

	for !file.eof() {
		buffer := file.read_bytes_at(max_bufsize, cur_pos)

		// spawn a thread to hash chunk
		threads << spawn hash_chunk(buffer, cur_pos, shared hashes)
		cur_pos += u64(max_bufsize)
	}

	// wait for goroutines to complete
	threads.wait()
	mut joint_hashes := []u8{}

	rlock hashes {
		mut keys := hashes.keys()
		keys.sort()

		for _, key in keys {
			joint_hashes << hashes[key]
		}
	}

	return sha256.sum(joint_hashes).hex()
}

fn hash_chunk(buffer []u8, cur_pos u64, shared hashes map[u64][]u8) {
	println('hashing the next ${buffer.len / int(FileSize.megabytes)} MB of data...')
	hash := sha256.sum(buffer)

	lock {
		hashes[cur_pos] = hash
	}
}
