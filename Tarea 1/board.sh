#!/bin/bash

random_text() {
    local length=$1
    cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c "$length" 
}

clean_board() {
    # Remove all the files and directories in the board directory
    rm -rf board/*
    # Remove the board directory itself
    rmdir board
}

# Global variable of file counter
file_counter=0

create_board_recursive() {
    local depth=$1
    local width=$2
    local files=$3

    if [ "$depth" -le 0 ]; then
        local i
        for ((i = 0; i < files; i++)); do
            touch "file$file_counter.txt"
            file_counter=$((file_counter + 1))
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
    local mode=$1
    local length=100

    fill_recursive() {
        for file in *; do
            if [ -d "$file" ]; then
                cd "$file" || continue
                fill_recursive
                cd ..
            elif [[ "$file" == *.txt ]]; then
                case "$mode" in
                    name)
                        : > "$file"   # truncate to empty
                        ;;
                    content|checksum|encrypted|signed)
                        random_text "$length" > "$file"
                        ;;
                esac
            fi
        done
    }

    cd board || return

    # Generate a temporary GNUPGHOME for key generation if signing
    if [[ "$mode" == "signed" ]]; then
        GNUPGHOME=$(mktemp -d)
        trap 'rm -rf "$GNUPGHOME"' EXIT

                    cat > "$GNUPGHOME/keyparams" <<EOF
%no-protection
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: fill
Name-Email: fill@example.com
Expire-Date: 0
%commit
EOF

        # Generate key quietly
        gpg --batch --quiet --homedir "$GNUPGHOME" --generate-key "$GNUPGHOME/keyparams"

        # Get key ID
        gpg_key=$(gpg --batch --quiet --homedir "$GNUPGHOME" --list-keys --with-colons | awk -F: '$1=="pub"{print $5; exit}')
    fi

    fill_recursive

    shopt -s globstar nullglob

    case "$mode" in
        encrypted)
            for file in **/*.txt; do
                [ -f "$file" ] || continue
                openssl enc -aes-256-cbc -salt -pbkdf2 -in "$file" -out "${file}.enc" -k "password"
                mv "${file}.enc" "$file"
            done
            ;;
        signed)
            for file in **/*.txt; do
                [ -f "$file" ] || continue
                gpg --batch --quiet --homedir "$GNUPGHOME" --yes --sign --local-user "$gpg_key" --output "${file}" "$file"
            done
            ;;
    esac

    shopt -u globstar nullglob

    cd ..
}
