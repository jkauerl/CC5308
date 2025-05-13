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
read t_name t_content t_checksum t_encrypted t_signed < < (place_treasure)

while true; do
    echo "Please enter a path to validate the treasure:"
    read -r path
    # Check if the path is the treasure path and if so exit the loop using the function verify
    read p_name p_contenp p_checksum p_encrypted p_signed < < (verify "$path")
    if [ "$p_name" = "$t_name" ] && [ "$p_content" = "$t_content" ] && [ "$p_checksum" = "$t_checksum" ] && [ "$p_encrypted" = "$t_encrypted" ] && [ "$p_signed" = "$t_signed" ]; then
        echo "Treasure found!"
        break
    else
        echo "Not the treasure path. Try again."
    fi
done