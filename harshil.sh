#!/bin/bash

# Function to create user
create_user() {
    local email="$1"
    local birthdate="$2"
    local groups="$3"
    local shared_folder="$4"

    # Extract username and set default password
    local username=$(echo "$email" | awk -F "@" '{print $1}' | tr -d '.')
    local password=$(date -d "$birthdate" +%m%Y)

    # Check if user already exists
    if id "$username" &>/dev/null; then
        echo "User $username already exists. Skipping."
        return
    fi

    # Create user with default password
    sudo useradd -m -s /bin/bash "$username"
    echo "$username:$password" | sudo chpasswd
    sudo chage -d 0 "$username"  # Force password change on first login

    # Create secondary groups and add user to them
    IFS=',' read -ra ADDR <<< "$groups"
    for group in "${ADDR[@]}"; do
        if ! getent group "$group" > /dev/null; then
            sudo groupadd "$group"
        fi
        sudo usermod -aG "$group" "$username"
    done

    # Create shared folder and set permissions
    if [ -n "$shared_folder" ]; then
        if [ ! -d "$shared_folder" ]; then
            sudo mkdir -p "$shared_folder"
            sudo chown :$group "$shared_folder"
            sudo chmod 770 "$shared_folder"
        fi
        sudo usermod -aG "$group" "$username"
        sudo ln -s "$shared_folder" "/home/$username/$(basename $shared_folder)"
    fi

    # Create alias for sudo users
    if [[ "$groups" == "sudo" ]]; then
        echo "alias shutdown='sudo shutdown -h now'" | sudo tee -a "/home/$username/.bashrc"
    fi

    echo "User $username created with default password $password."
}

# Main script
input_file="$1"

if [[ "$input_file" =~ ^https?:// ]]; then
    wget -O /tmp/users.csv "$input_file"
    input_file="/tmp/users.csv"
fi

if [ ! -f "$input_file" ]; then
    echo "Input file not found!"
    exit 1
fi

# Read CSV file and create users
while IFS="," read -r email birthdate groups shared_folder; do
    # Skip header
    [[ "$email" == "e-mail" ]] && continue

    create_user "$email" "$birthdate" "$groups" "$shared_folder"
done < "$input_file"

echo "User creation and configuration completed."

