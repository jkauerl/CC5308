#!/bin/bash

clean_board() {
    cd board || return
    rm -rf *
    cd ..
}

create_board_recursive() {
    local depth=$1
    local width=$2
    local files=$3

    if [ "$depth" -le 0 ]; then
        local i
        for ((i = 0; i < files; i++)); do
            touch "file_$i.txt"
        done
    else
        local i
        for ((i = 0; i < width; i++)); do
            mkdir "dir$i"
            cd "dir$i"
            create_board_recursive $((depth - 1)) "$width" "$files"
            cd ..
        done
    fi
}

create_board() {
    mkdir -p board
    cd board || return
    create_board_recursive "$@"
    cd ..
}

if [ -d board ]; then
    clean_board
    echo "Cleaned existing board directory."
fi

echo "Creating board directory..."
create_board 3 2 4
