#!/bin/bash

source ./board.sh
source ./controller.sh

local name=$1
local content=$2
local checksum=$3
local encrypted=$4
local signed=$5

if [ -d board ]; then
    clean_board
    echo "Cleaned existing board directory."
fi

echo "Creating board directory..."
create_board 3 2 4

echo "Filling board with random content..."
fill_board "$name" "$content" "$checksum" "$encrypted" "$signed"

echo "Placing treasure randomly..."
declare -a treasure_info
place_treasure treasure_info

t_name=${treasure_info[0]}
t_content=${treasure_info[1]}
t_checksum=${treasure_info[2]}
t_encrypted=${treasure_info[3]}
t_signed=${treasure_info[4]}

while true; do
    echo "Please enter a path to validate the treasure:"
    read -r path
declare -a verify_result
    if verify "$path" verify_result; then
        p_name="${verify_result[0]}"
        p_content="${verify_result[1]}"
        p_checksum="${verify_result[2]}"
        p_encrypted="${verify_result[3]}"
        p_signed="${verify_result[4]}"

        if [ "$p_name" = "$t_name" ] && 
        [ "$p_content" = "$t_content" ] && \
        [ "$p_checksum" = "$t_checksum" ] && \
        [ "$p_encrypted" = "$t_encrypted" ] && \
        [ "$p_signed" = "$t_signed" ]; then
            echo "Treasure found!"
            break
        fi
    else
        echo "Not the treasure path. Try again."
    fi
done