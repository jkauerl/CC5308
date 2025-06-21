use nix::sys::wait::waitpid;
use nix::unistd::{execvp, fork, ForkResult};
use std::env;
use std::ffi::CString;
use std::fs::{File, OpenOptions};
use std::io::{self, Write};
use std::io::{BufRead, BufReader, BufWriter};
use std::process;

const HISTORY_FILE: &str = ".shell-history";

fn load_history() -> Vec<String> {
    let mut history = Vec::new();
    // Load history from the file in the user's home directory
    if let Some(mut path) = dirs::home_dir() {
        path.push(HISTORY_FILE);

        // If the file exists, read it line by line and store the commands in a vector
        if let Ok(file) = File::open(path) {
            let reader = BufReader::new(file);
            for line in reader.lines() {
                if let Ok(cmd) = line {
                    history.push(cmd);
                }
            }
        }
    }
    history
}

fn append_to_history(line: &str) {
    // Append the command to the history file in the user's home directory
    if let Some(mut path) = dirs::home_dir() {
        path.push(HISTORY_FILE);

        // Open the file in append mode, creating it if it doesn't exist
        if let Ok(file) = OpenOptions::new().create(true).append(true).open(path) {
            let mut writer = BufWriter::new(file);
            let _ = writeln!(writer, "{}", line);
        }
    }
}

fn show_prompt() {
    print!("mi-rust-shell-prompt> ");
    io::stdout().flush().unwrap();
}

fn read_input() -> Option<String> {
    let mut input = String::new();

    match io::stdin().read_line(&mut input) {
        // Removes the trailing newline character
        Ok(n) if n > 0 => Some(input.trim().to_string()),
        _ => None,
    }
}

fn substitute_env_variables(input: &str) -> String {
    let mut result = String::new();
    let mut chars = input.chars().peekable();

    while let Some(c) = chars.next() {
        if c == '$' {
            let mut var_name = String::new();
            while let Some(&next) = chars.peek() {
                if next.is_alphanumeric() || next == '_' {
                    var_name.push(next);
                    chars.next();
                } else {
                    break;
                }
            }
            if let Ok(val) = env::var(&var_name) {
                result.push_str(&val);
            } else {
                // If the variable is not found, just keep "$NAME"
                result.push('$');
                result.push_str(&var_name);
            }
        } else {
            result.push(c);
        }
    }

    result
}

fn parse_command(input: &str) -> Vec<&str> {
    input.split_whitespace().collect()
}

fn execute_command(cmd: &[&str], history: &Vec<String>) {
    if cmd.is_empty() {
        return;
    }

    // Using match to handle build-in commands and later on execute external commands
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
    // Load the command history from the file
    let mut history = load_history();

    loop {
        // Show the prompt and read input from the user
        show_prompt();

        // Read a line of input from the user
        let raw_line = match read_input() {
            Some(line) => line,

            // If input is empty or EOF, exit the loop
            None => {
                println!();
                break;
            }
        };

        // If the input is empty, skip to the next iteration
        if raw_line.trim().is_empty() {
            continue;
        }

        // Append the command to the history and store it in the history vector
        append_to_history(&raw_line);
        history.push(raw_line.clone());

        // Substitute environment variables, parse the command, and execute it
        let input = substitute_env_variables(&raw_line);
        let cmd = parse_command(&input);
        execute_command(&cmd, &history);
    }
}
