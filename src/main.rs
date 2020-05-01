use std::thread;
use std::io::stdin;
use std::env;
use std::fs::File;
use std::io::prelude::*;
use std::io::BufReader;

mod ts {
    struct Segment {
        url: String,
        seq: u32,
        name: String
    }
}

#[derive(Debug)]
struct CliArgs {
    m3u8: String,
    threads: u32,
    combine: bool
}

fn reader() {
    loop {
        let byte = stdin().lock().bytes().next();
        println!("{:?}", byte);
    }
}

fn get_args() -> CliArgs {
    let mut args = CliArgs {
        m3u8: String::new(),
        threads: 8,
        combine: true
    };
    let mut i = env::args().skip(1);
    while let Some(arg) = i.next() {
        if arg == "-m" {
            let vl = i.next().expect("-m takes a string, bro.");
            args.m3u8 = vl.clone();
        }
        else if arg == "-t" {
            args.threads = i.next()
                            .expect("-t takes a u32, bro.")
                            .parse()
                            .unwrap();
        }
        else if arg == "-c" {
            args.combine = !args.combine;
        }
        else {
            println!("Excuse me, what is this: {}?", arg);
        }
    }
    args
}

fn open_m3u8(fname: &str) -> std::io::Result<File> {
    match File::open(fname) {
        Ok(fp) => Ok(fp),
        Err(e) => Err(e)
    }
}

fn read_m3u8(f: File) -> Vec<String> {
    let mut reader = BufReader::new(f);
    let mut list = String::new();
    match reader.read_to_string(&mut list) { _ => () };

    list.split("\n")
        .collect::<Vec<_>>()
        .iter()
        .filter(|x| {
            match x.chars().nth(0) {
                Some(c) => c != '#',
                None => {
                    false
                }
            }
        })
        .map(|x| x.to_string())
        .collect()
}

fn main() {
    let args = get_args();
    let m3u8 = match open_m3u8(&args.m3u8) {
        Ok(f) => f,
        Err(e) => {
            println!("Error opening m3u8: {}", e);
            return;
        }
    };
    let parts = read_m3u8(m3u8);

    //thread::spawn(|| {
        //reader();
    //}).join().unwrap();
}
