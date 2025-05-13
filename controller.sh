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
    local -n out_array=$1  # Reference to caller's array

    cd board || return 1

    recursive_place() {
        txt_files=(*.txt)
        if [ ${#txt_files[@]} -gt 0 ]; then
            random_index=$((RANDOM % ${#txt_files[@]}))
            selected_file="${txt_files[$random_index]}"

            echo "Treasure!" >> "$selected_file"

            # a) Name
            name="$selected_file"

            # b) Content
            content=$(<"$selected_file")

            # c) Checksum
            checksum=$(sha256sum "$selected_file" | awk '{print $1}')

            # d) Encrypt
            passphrase=$(openssl rand -base64 16)
            openssl enc -aes-256-cbc -salt -in "$selected_file" -out "${selected_file}.enc" -pass pass:"$passphrase"
            mv "${selected_file}.enc" "$selected_file"

            # e) Sign
            key_name="key_$(date +%s)"
            gpg --batch --gen-key <<EOF
Key-Type: default
Key-Length: 2048
Name-Real: TreasureSigner
Name-Email: signer@example.com
Expire-Date: 0
%no-protection
%commit
EOF

            key_fpr=$(gpg --list-keys --with-colons | grep '^fpr' | head -n1 | cut -d: -f10)

            gpg --default-key "$key_fpr" --output "${selected_file}.gpg" --sign "$selected_file"
            mv "${selected_file}.gpg" "$selected_file"
            pubkey=$(gpg --armor --export "$key_fpr")

            # Assign to output array
            out_array=(
                "$name"
                "$content"
                "$checksum"
                "$passphrase"
                "$pubkey"
            )
            return
        fi

        # Recurse
        subdirs=()
        for dir in */; do
            [ -d "$dir" ] && subdirs+=("$dir")
        done

        if [ ${#subdirs[@]} -eq 0 ]; then
            echo "No more directories to search." >&2
            return 1
        fi

        random_index=$((RANDOM % ${#subdirs[@]}))
        cd "${subdirs[$random_index]}" || return
        recursive_place
        cd .. || return
    }

    recursive_place
}

verify() {
    local path=$1
    local -n out_array=$2 

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
