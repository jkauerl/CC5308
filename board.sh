clean_board() {
    if [ -d board ]; then
        cd board || return
        rm -rf *
        cd ..
    else
        echo "Directory 'board' does not exist."
    fi
}

create_board_recursive() {
    local depth=$1
    local width=$2
    local files=$3

    if [ "$depth" -le 0 ]; then
        for ((i = 0; i < files; i++)); do
            touch "file_$i.txt"
        done
        return
    fi

    for ((i = 0; i < width; i++)); do
        mkdir "dir$i"
        cd "dir$i" || return
        create_board_recursive $((depth - 1)) "$width" "$files"
        cd ..
    done
}

create_board() {
    mkdir -p board
    cd board || return
    create_board_recursive "$@"
    cd ..
}

clean_board

create_board 2 3 2  # depth=2, width=3, files=2
