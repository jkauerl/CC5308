use nix::sys::wait::waitpid;
use nix::unistd::{ForkResult, execvp, fork};
use std::ffi::CString;
use std::io::{self, Write};

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

    // Convert the command to a CString
    let cmd_c = match CString::new(cmd[0]) {
        Ok(s) => s,
        Err(_) => {
            eprintln!("Comando inválido");
            return;
        }
    };

    let args_c: Vec<CString> = cmd
        .iter()
        .filter_map(|&arg| CString::new(arg).ok())
        .collect();

    match unsafe { fork() } {
        Ok(ForkResult::Child) => {
            // In the child process: execute the command
            let result = execvp(&cmd_c, &args_c);
            if result.is_err() {
                let e = result.unwrap_err();
                eprintln!("Error al ejecutar '{}': {}", cmd[0], e);
                std::process::exit(1); // Salida con error si exec falla
            }
        }
        Ok(ForkResult::Parent { child }) => {
            // In the parent process: wait for the child to finish
            let _ = waitpid(child, None);
        }
        Err(e) => {
            eprintln!("Error al hacer fork: {}", e);
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
