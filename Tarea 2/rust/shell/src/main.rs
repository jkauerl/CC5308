use nix::sys::wait::waitpid;
use nix::unistd::{ForkResult, execvp, fork};
use std::env;
use std::ffi::CString;
use std::io::{self, Write};
use std::process;

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

fn execute_command(cmd: &[&str], history: &Vec<String>) {
    if cmd.is_empty() {
        return;
    }

    match cmd[0] {
        "cd" => {
            let home = env::var("HOME").unwrap_or_else(|_| "/".to_string());
            let target = if cmd.len() > 1 { cmd[1] } else { &home };
            if let Err(e) = env::set_current_dir(target) {
                eprintln!("cd: {}", e);
            }
        }
        "exit" => {
            let code = if cmd.len() > 1 {
                cmd[1].parse::<i32>().unwrap_or(0)
            } else {
                0
            };
            process::exit(code);
        }
        "pwd" => match env::current_dir() {
            Ok(path) => println!("{}", path.display()),
            Err(e) => eprintln!("pwd: {}", e),
        },
        "export" => {
            if cmd.len() < 2 {
                eprintln!("export: Argument required NAME=VALUE");
                return;
            }
            let eq_pos = cmd[1].find('=');
            match eq_pos {
                Some(pos) => {
                    let key = &cmd[1][..pos];
                    let val = &cmd[1][pos + 1..];
                    unsafe {
                        env::set_var(key, val);
                    }
                }
                None => {
                    eprintln!("export: invalid argument, missing '='");
                }
            }
        }
        "unset" => {
            if cmd.len() < 2 {
                eprintln!("unset: name of the variable to unset is required");
                return;
            }
            unsafe {
                env::remove_var(cmd[1]);
            }
        }
        "history" => {
            for (i, command) in history.iter().enumerate() {
                println!("{} {}", i + 1, command);
            }
        }
        // If the command is not a built-in command, execute it using execvp
        _ => {
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
                    let _ = result.unwrap_or_else(|e| {
                        eprintln!("Error when executing '{}': {}", cmd[0], e);
                        process::exit(1);
                    });
                }
                Ok(ForkResult::Parent { child }) => {
                    // In the parent process: wait for the child to finish
                    let _ = waitpid(child, None);
                }
                Err(e) => {
                    eprintln!("Error when doing fork: {}", e);
                }
            }
        }
    }
}

fn main() {
    let mut history = Vec::new();

    loop {
        show_prompt();
        let input = match read_input() {
            Some(line) => line,
            None => {
                println!();
                break;
            }
        };

        if input.trim().is_empty() {
            continue;
        }

        history.push(input.clone());

        let cmd = parse_command(&input);
        execute_command(&cmd, &history);
    }
}
