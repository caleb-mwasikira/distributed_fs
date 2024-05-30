module utils

import os

pub fn parse_filepath(ofpath string) string {
	home_dir := os.home_dir()

	fpath := match true {
		ofpath.starts_with("~/") {
			os.join_path(home_dir, ofpath.all_after("~/"))
		}
		ofpath.starts_with("~") {
			os.join_path(home_dir, ofpath.all_after("~"))
		}
		else {
			ofpath
		}
	}
	return fpath
}