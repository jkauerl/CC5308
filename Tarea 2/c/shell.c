#include <stdio.h>

void show_prompt() {
    // TODO: mostrar prompt
}

char* read_input() {
    // TODO: leer input
    return NULL;
}

char** parse_command(char* buf) {
    // TODO: parsear comando
    return NULL;
}

void execute_command(char** cmd) {
    // TODO: ejecutar comando
}

int main(int argc, char *argv[]) {
  while (1) {
    show_prompt();
    char* buf = read_input();
    char** cmd = parse_command(buf);
    execute_command(cmd);
  }
  return 0;
}

