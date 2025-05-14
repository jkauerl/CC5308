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

    shopt -s nullglob
    local -n out_array=$1  # Reference to caller's array

    cd board || return 1

    recursive_place() {
        # Check if there are no subdirectories
        directories=(*/)
        test=()
        echo "Directories found: ${#directories[@]}"
        echo "content: ${#test[@]}"
        if [ ${#directories[@]} -eq 0 ]; then
            # Get .txt files in this leaf directory
            txt_files=(*.txt)
            if [ ${#txt_files[@]} -eq 0 ] || [ "${txt_files[0]}" = "*.txt" ]; then
                echo "No .txt files in $(pwd), skipping."
                return 1
            fi

            # Randomly select one .txt file
            random_index=$((RANDOM % ${#txt_files[@]}))
            selected_file="${txt_files[$random_index]}"

            echo "Treasure!" >> "$selected_file"

            # a) Name
            name="$selected_file"

            # b) Content
            content=$(<"$selected_file")

            # c) Checksum
            checksum=$(sha256sum "$selected_file" | awk '{print $1}')

            # d) Sign
            gpg --default-key F6AD6E517CD8C16A66884788F0F46513D3A233CE --output "${selected_file}.sig" --detach-sign "$selected_file"
            signature=$(base64 "${selected_file}.sig")
            rm -f "${selected_file}.sig"

            # e) Print the full path of the treasure
            echo "Treasure placed in: $(pwd)/$selected_file"

            # f) Assign output
            out_array=(
                "$name"
                "$content"
                "$checksum"
                "$signature"
            )
            return 0
        fi

        # Recurse into a random subdirectory
        subdirs=()
        for dir in */; do
            [ -d "$dir" ] && subdirs+=("$dir")
        done

        if [ ${#subdirs[@]} -eq 0 ]; then
            echo "No more directories to search." >&2
            return 1
        fi

        random_index=$((RANDOM % ${#subdirs[@]}))
        selected_subdir="${subdirs[$random_index]}"
        echo "Entering subdirectory: $selected_subdir"
        cd "$selected_subdir" || return
        recursive_place
        cd .. || return
    }

    recursive_place
    cd .. || return
    shopt -u nullglob
}

verify() {
    local path=$1
    local -n out_array=$2 

    # Check if the path is a relative or global path
    if [[ "$path" != /* ]]; then
        path=$(realpath "board/$path")
    fi

    # Now check if the resolved path exists
    if [[ ! -f "$path" ]]; then
        echo "Error: File '$path' does not exist." >&2
        return 1
    fi

    local content
    content=$(<"$path")

    if [[ "$content" == *"Treasure!"* ]]; then
        local p_name="TreasureFound"
        local p_content="$content"
        local p_checksum
        p_checksum=$(md5sum "$path" | awk '{print $1}')
        local p_encrypted
        p_encrypted=$(echo "$content" | openssl enc -base64)
        local p_signed
        p_signed=$(echo "$content" | openssl dgst -sha256 | awk '{print $2}')

        out_array=(
            "$p_name"
            "$p_content"
            "$p_checksum"
            "$p_encrypted"
            "$p_signed"
        )
        return 0
    else
        echo "No treasure found in $path." >&2
        return 1
    fi
}

