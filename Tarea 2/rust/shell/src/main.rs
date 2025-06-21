use std::io::{self, Write};
use std::process::{Command, Stdio};

fn show_prompt() {
    print!("mi-rust-shell-prompt> ");
    io::stdout().flush().unwrap();
}

fn read_input() -> Option<String> {
    let mut input = String::new();
    match io::stdin().read_line(&mut input) {
        Ok(n) if n > 0 => Some(input.trim().to_string()),
        _ => None,
    }
}

fn parse_command(input: &str) -> Vec<&str> {
    input.split_whitespace().collect()
}

fn execute_command(cmd: &[&str]) {
    if cmd.is_empty() {
        return;
    }

    let child = Command::new(cmd[0])
        .args(&cmd[1..])
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .spawn();

    match child {
        Ok(mut child_proc) => {
            let _ = child_proc.wait();
        }
        Err(e) => {
            eprintln!("Error al ejecutar '{}': {}", cmd[0], e);
        }
    }
}

fn main() {
    loop {
        show_prompt();
        let input = match read_input() {
            Some(line) => line,
            None => {
                println!();
                break;
            }
        };

        let cmd = parse_command(&input);
        execute_command(&cmd);
    }
}
