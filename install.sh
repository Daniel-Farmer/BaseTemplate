#!/bin/bash

# Updates the system and installs dependencies.
sudo apt update -y -q
sudo apt install jq -y -q

# Creates an example JSON file.
cat <<EOF > /root/details.json
{
    "userid": "danielfarmer",
    "projectid": "89422",
    "prompt": "when the server starts, say hello world"
}
EOF

# Creates the project directory.
project_dir=$(jq -r '.projectid' /root/details.json)
mkdir -p "$project_dir"

# Removes the installation file.
rm -r install.sh
