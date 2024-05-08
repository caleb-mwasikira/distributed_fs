import os
import flag
import time
import lib { hash_file }

struct Args {
pub:
	files []string
	size  u32      @[omitempty]
}

fn parse_cmd_args() !Args {
	max_files := 5
	mut fnames := []string{}
	mut fp := flag.new_flag_parser(os.args)

	fp.application('dfs')
	fp.version('v0.0.1')

	// comment this, if you expect arbitrary texts after the options
	fp.limit_free_args(0, max_files) or {
		println(fp.usage())
		return error('exceeded max number of allowable files ${max_files}')
	}

	fp.description('A distributed file system manager')
	fp.skip_executable()

	u_fnames := fp.string_multi('files', `f`, 'enter the paths of the files you wish to upload')
	u_extra_fnames := fp.finalize()!

	fnames << u_fnames
	fnames << u_extra_fnames

	// mandatory argument -f, --filename
	if fnames.len == 0 {
		println(fp.usage())
		exit(1)
	}

	return Args{
		files: fnames
		size: 0
	}
}

fn main() {
	args := parse_cmd_args()!

	// validate user filenames
	valid_fnames := args.files.filter(fn (fname string) bool {
		is_valid_fname := os.is_file(fname)
		if !is_valid_fname {
			eprintln("path '${fname}' is NOT a valid file, dropping file...")
		}
		return is_valid_fname
	})

	if valid_fnames.len == 0 {
		eprintln('\nall provided paths were invalid. exiting...')
		exit(1)
	}

	for _, fname in valid_fnames {
		stop_watch := time.new_stopwatch()

		hash := hash_file(fname) or {
			eprintln('failed to get file hash ${err}')
			continue
		}
		println('${hash}\t${fname}\t${stop_watch.elapsed().seconds()}')
	}
}
