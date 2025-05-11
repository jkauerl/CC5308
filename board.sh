clean_board() {
    if [ -d board ]; then
        cd board || return
        rm -rf *
    else
        echo "Directory 'board' does not exist."
    fi
}

create_board() {
    local depth=$1
    local width=$2
    local files=$3

    mkdir board

    cd board

    for ((i = 0; i < depth; i++)); do
        mkdir "depth_$i"
        cd "depth_$i" || return

        for ((j = 0; j < width; j++)); do
            mkdir "width_$j"
            cd "width_$j" || return

            for ((k = 0; k < files; k++)); do
                touch "file_$k.txt"
            done

            cd .. || return
        done

        cd .. || return
    done

    cd .. || return
}

clean_board

create_board