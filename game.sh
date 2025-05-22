#!/bin/bash

source ./board.sh
source ./controller.sh

mode=$1

if [ -d board ]; then
    clean_board
    echo "Cleaned existing board directory."
fi

echo "Creating board directory..."
# Parameters are: depth, width, files
create_board 1 2 2  

echo "Filling board with random content..."
fill_board "$mode"

echo "Placing treasure randomly..."
t_key=$(place_treasure "$mode")

while true; do
    echo "Please enter a path (board/ is already included) to validate the treasure:"
    read -r path

    # For current mode, pick corresponding treasure_info element as key:
    case "$mode" in
        name) key="${t_key}" ;;
        content) key="${t_key}" ;;
        checksum) key="${t_key}" ;;
        encrypted) key="${t_key}" ;;
        signed) key="${t_key}" ;;
    esac

    if verify "$path" "$mode" "$key"; then
        echo "Treasure found!"
        break
    else
        echo "Not the treasure path. Try again."
    fi
done
