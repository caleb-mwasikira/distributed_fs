module lib 

import os
import rand

pub fn fill_file_with_random_data(fpath string, size u32) ! {
	mut file := os.open_file(fpath, 'wb', 700)!
	defer {
		file.close()
	}

	mut i_size := size
	buf_size := 10 * u32(ByteSize.kilobytes) // 10KB

	for i_size != 0 {
		n_bytes := match true {
			i_size < buf_size { i_size }
			else { u32(buf_size) }
		}

		println('filling file with ${n_bytes} bytes of random data...')
		buffer := rand.bytes(n_bytes)!

		unsafe {
			file.write_full_buffer(buffer, usize(buffer.len))!
		}

		i_size -= n_bytes
	}
}