module utils

pub enum RequestType {
	@none
	download
	search
	upload
}

pub struct Request {
pub:
	id      string      @[required]
	typ     RequestType @[required]
	payload string      @[required]
}

pub struct Response {
pub:
	id string @[required]
pub mut:
	ack bool
}
