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
    local mode=$1

    shopt -s nullglob
    cd board || return 1

    recursive_place() {
        directories=(*/)
        if [ ${#directories[@]} -eq 0 ]; then
            # Base case: no more directories, check for .txt files
            txt_files=(*.txt)
            if [ ${#txt_files[@]} -eq 0 ] || [ "${txt_files[0]}" = "*.txt" ]; then
                echo "No .txt files in $(pwd), skipping." >&2
                return 1
            fi

            random_index=$((RANDOM % ${#txt_files[@]}))
            selected_file="${txt_files[$random_index]}"

            # Replace content with "Treasure!" for all modes except encrypted/signed
            if [[ "$mode" != "encrypted" && "$mode" != "signed" ]]; then
                echo "Treasure!" > "$selected_file"
            fi

            # Prepare output value based on mode
            case "$mode" in
                name)
                    echo "$selected_file"
                    ;;
                content)
                    content=$(<"$selected_file")
                    echo "$content"
                    ;;
                checksum)
                    checksum=$(sha256sum "$selected_file" | awk '{print $1}')
                    echo "$checksum"
                    ;;
                encrypted)
                    new_passphrase=$(openssl rand -base64 12)
                    echo "Treasure!" > "$selected_file"
                    openssl enc -aes-256-cbc -salt -pbkdf2 -in "$selected_file" -out "${selected_file}.enc" -k "$new_passphrase"
                    mv "${selected_file}.enc" "$selected_file"
                    echo "$new_passphrase"
                    ;;
                signed)
                    GNUPGHOME=$(mktemp -d)
                    trap "rm -rf '$GNUPGHOME'" EXIT

                    cat > "$GNUPGHOME/keyparams" <<EOF
%no-protection
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: Treasure Signer
Name-Email: treasure@example.com
Expire-Date: 0
%commit
EOF

                    gpg --batch --quiet --homedir "$GNUPGHOME" --generate-key < "$GNUPGHOME/keyparams"

                    new_key_id=$(gpg --batch --quiet --homedir "$GNUPGHOME" --list-keys --with-colons | awk -F: '$1 == "pub" {print $5; exit}')

                    echo "Treasure!" > "$selected_file"

                    gpg --batch --quiet --homedir "$GNUPGHOME" --yes \
                        --local-user "$new_key_id" \
                        --output "$selected_file" \
                        --sign "$selected_file"

                    if [[ $? -ne 0 ]]; then
                        echo "Error: GPG signing failed for $selected_file" >&2
                        return 1
                    fi

                    pubkey=$(gpg --batch --quiet --homedir "$GNUPGHOME" --armor --export "$new_key_id")
                    echo "$pubkey"
                    ;;
            esac

            # echo "Treasure placed in: $(pwd)/$selected_file" >&2
            return 0
        fi

        # Recursive case: go into a random subdirectory

        # Get a list of subdirectories
        subdirs=()
        for dir in */; do
            [ -d "$dir" ] && subdirs+=("$dir")
        done

        # Select a random subdirectory
        random_index=$((RANDOM % ${#subdirs[@]}))
        selected_subdir="${subdirs[$random_index]}"

        # Cd into the selected subdirectory and call the function recursively
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
    local mode=$2
    local key=$3

    # Resolve path relative to board if needed
    if [[ "$path" != /* ]]; then
        path=$(realpath "board/$path")
    fi

    if [[ ! -f "$path" ]]; then
        echo "Error: File '$path' does not exist." >&2
        return 1
    fi

    echo "Verifying $path with mode $mode"

    case "$mode" in
        name)
            local filename
            filename=$(basename "$path")
            [[ "$filename" == "$key" ]]
            return
            ;;
        content)
            local content
            content=$(<"$path")
            [[ "$content" == "$key" ]]
            return
            ;;
        checksum)
            local checksum
            checksum=$(sha256sum "$path" | awk '{print $1}')
            [[ "$checksum" == "$key" ]]
            return
            ;;
        encrypted)
            local tmpfile
            tmpfile=$(mktemp)
            if openssl enc -d -aes-256-cbc -salt -pbkdf2 -in "$path" -out "$tmpfile" -k "$key" &>/dev/null; then
                rm -f "$tmpfile"
                return 0
            else
                rm -f "$tmpfile"
                return 1
            fi
            ;;
        signed)
            local GNUPGHOME
            GNUPGHOME=$(mktemp -d)

            # Import the public key silently
            echo "$key" | gpg --batch --quiet --homedir "$GNUPGHOME" --import &>/dev/null
            if [[ $? -ne 0 ]]; then
                rm -rf "$GNUPGHOME"
                return 1
            fi

            # Set key trust silently
            key_fingerprint=$(gpg --homedir "$GNUPGHOME" --with-colons --list-keys | awk -F: '$1 == "fpr" {print $10; exit}')
            if [[ -n "$key_fingerprint" ]]; then
                printf '5\ny\n' | gpg --homedir "$GNUPGHOME" --batch --yes --quiet --command-fd 0 --status-fd 1 --edit-key "$key_fingerprint" trust &>/dev/null
            fi

            # Verify the signature silently
            if gpg --batch --quiet --homedir "$GNUPGHOME" --verify "$path" &>/dev/null; then
                rm -rf "$GNUPGHOME"
                return 0
            else
                rm -rf "$GNUPGHOME"
                return 1
            fi
            ;;
    esac
}
