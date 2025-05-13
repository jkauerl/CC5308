#!/bin/bash

count_directories() {
    count=0
    for directory in */; do
        if [ -d "$directory" ]; then
            count=$((count + 1))
        fi
    done
    return $count
}

random_number() {
    local max=$1
    return $((RANDOM % max))
}

place_treasure() {
    cd board || return

    # Recursive function to place the treasure in a random directory
    recursive_place() {
        # Check if the current directory contains a file with .txt extension
        for file in *; do
            if [[ "$file" == *.txt ]]; then
                # Place the treasure in this file
                echo "Placing treasure in $file"
                echo "Treasure!" >> "$file"
                return
            fi
        done

        # If no .txt file is found go deeper into the directory structure
        # by going into one random subdirectory
        directories=count_directories
        next_directoyr=random_number "$directories"
        local i=0
        cd "$next_directory" || return
        # Recursively call the function to place the treasure
        recursive_place
        cd .. || return 
    }
}

verify() {
    # Function that given a path to a file checks if it contains the treasure
    # If so, it returns the treasure name, content, checksum, encrypted and signed
    # Otherwise it returns an error message
    local path=$1
if [ -f "$path" ]; then
    content=$(<"$path")
    if [[ "$content" == *"Treasure!"* ]]; then
        echo "Treasure found in $path"
        return 0
    else
        echo "No treasure found in $path"
        return 1
    fi
else
    echo "Invalid path: $path"
    return 1
fi
}
