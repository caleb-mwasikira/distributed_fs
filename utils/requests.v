module utils

pub enum RequestType {
	@none
	download
	search
	upload
}

pub struct Request {
pub:
	id      u64         @[required]
	typ     RequestType @[required]
	payload string      @[required]
}

pub struct Response {
pub:
	id          u64         @[required]
	request_typ RequestType @[required]
pub mut:
	ack bool
}
