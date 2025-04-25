#!/bin/bash

# Update the package list
sudo apt update -y -q

# Check if jq is installed and install it if needed
dpkg -l | grep -qw jq || sudo apt install jq -y -q

# Create an example JSON file
cat <<EOF > /root/details.json
{
    "userid": "danielfarmer",
    "projectid": "89422",
    "prompt": "when the server starts, say hello world"
}
EOF

# Create the project directory based on the projectid in the JSON file
project_dir=$(jq -r '.projectid' /root/details.json)
mkdir -p "$project_dir"

# Remove the installation file
rm -r install.sh
