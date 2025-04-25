#!/bin/bash

# Update the system and install requirements
sudo apt update -y -q
sudo apt install jq -y -q

# Create valid details.json
cat <<EOF > /root/details.json
{
    "userid": "danielfarmer",
    "projectid": "89422",
    "prompt": "when the server starts say hello world"
}
EOF

# Extract projectid and create a directory
project_dir=$(jq -r '.projectid' /root/details.json)
mkdir -p "$project_dir"

echo "Project directory created: $project_dir"
