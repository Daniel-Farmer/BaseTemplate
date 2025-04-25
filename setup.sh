#!/bin/bash

# updates the system and installs requirements
sudo apt update -y -q
sudo apt get jq -y -q 

cat <<EOF > details.json
{
    "userid": "danielfarmer",
    "projectid": "89422",
    "prompt": "when the server starts say hello world",
}

project_dir=$(jq -r '.projectid' details.json)

mkdir -p "$project_dir"


rm -r setup.sh
