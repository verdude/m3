use std::env;
use std::io::BufReader;
use std::io::{self};
use std::io::{Error, ErrorKind};
use std::fs::File;
use std::io::prelude::*;
use std::ffi::OsString;

use std::fs::{self};

fn first_arg() -> String {
    env::args().skip(1).next().expect("Hello, I need some env vars please")
}

fn num_segments(fname: &str) -> io::Result<u32> {
    let mut total = 0;
    for reader in fs::read_dir(fname)? {
        let entry = reader?;
        if is_segment(fname, entry.file_name())? { 
            total += 1;
        }
    }
    Ok(total)
}

fn is_segment(dir: &str, filename: OsString) -> io::Result<bool> {
    let f_as_string = match filename.into_string() {
        Ok(s) => s,
        Err(e) => return Err(Error::new(ErrorKind::Other, format!("Couldn't turn {:?} into a string", e)))
    };
    if f_as_string == "combined.ts" {
      // don't count the combined file...we know it is a segment
      return Ok(false);
    }
    let fullpath = format!("{}/{}", dir, f_as_string);
    let mut f = File::open(fullpath)?;
    let mut buffer = Vec::new();

    f.seek(io::SeekFrom::Start(188))?;
    {
        let reference = io::Read::by_ref(&mut f);
        // original file still usable, read the rest
        reference.take(1).read_to_end(&mut buffer)?;
    }

	if buffer.len() == 0 {
		return Ok(false);
	}
    // missing sync byte
    if buffer[0] != 0x47 {
        return Ok(false);
    }

    f.take(1).read_to_end(&mut buffer)?;
	if buffer.len() == 0 {
		return Ok(false);
	}
    if (buffer[1] & 0xf0) != 0x40 {
        Ok(false)
    }
    else { Ok(true) }
}

fn get_expected(fname: &str) -> (u32, String) {
    let tslist =  match File::open(format!("{}/manny.m3u8", fname))  {
        Ok(f) => f,
        Err(e) => {
            panic!("{}::{}::Exiting", e, fname);
        }
    };

    let mut reader = BufReader::new(tslist);
    let mut list = String::new();
    match reader.read_to_string(&mut list) { _ => () };

    let mut lines = 0;
    for line in list.split('\n') {
        if line != "" && line.chars().nth(0).expect("couldn't unwrap") != '#' {
            lines += 1;
        }
    }
    (lines, "testmp".to_string())
}

fn main() {
    let fname = first_arg();
    let (expected, _n) = get_expected(fname.as_str());
    let actual = match num_segments(fname.as_str()) {
        Ok(e) => e,
        Err(e) => panic!("{}", e)
    };

    if actual != expected {
		println!("{}: {} -> {}", fname, actual, expected);
    }
}
