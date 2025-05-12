#!/bin/bash

random_text() {
    local length=$1
    cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c "$length" 
}

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

fill_board() {
    local name=$1
    local content=$2
    local checksum=$3
    local encrypted=$4
    local signed=$5
    local length=100

    fill_recursive() {
        for file in *; do
            if [ -d "$file" ]; then
                cd "$file" || continue
                fill_recursive
                cd ..
            elif [[ "$file" == *.txt ]]; then
                echo "Filling $file with random content..."
                random_text "$length" > "$file"

                if [ "$checksum" = true ]; then
                    sha256sum "$file" > "$file"
                fi
                if [ "$encrypted" = true ]; then
                    openssl enc -aes-256-cbc -salt -in "$file" -out "$file" -k secret
                fi
                if [ "$signed" = true ]; then
                    gpg --sign "$file"
                fi
            fi
        done
    }

    cd board || return
    fill_recursive
    cd ..
}

if [ -d board ]; then
    clean_board
    echo "Cleaned existing board directory."
fi

echo "Creating board directory..."
create_board 3 2 4

echo "Filling board with random content..."
fill_board "random_text" false false false false
