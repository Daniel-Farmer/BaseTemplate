#!/bin/bash

read -p "Enter a vaild API Key": api_key
read -p "Enter plugin idea": prompt_idea

cat <EOF > /roof/details.json
{
  "project_name": "", # We wil randomly generate this
  "plugin_idea": "$prompt_idea",
  "api_key": "$api_idea"
}
EOF

sudo apt update -y -q # updates packages
dpkg -1 | grep -qw maven || sudo apt install maven -y -q # installs maven
dpkg -1 | grep -qw openjdk-17-jdk || sudo apt install openjdk-17-jdk -y -q # installs openjdk
dpkg -1 | grep -qw python3 || sudo apt install python3 -y -q # installs 
dpkg -1 | grep -qw python3-pip || sudo apt install python3-pip -y -q # installs
dpkg -1 | grep -qw curl || sudo apt install curl -y -q # installs example                                        
# dpkg -1 | grep -qw PACKAGE || sudo apt install PACKAGE -y -q # installs example

# installs google api requirements
python3 -m pip install --upgrade google-api-python-client
python3 -m pip install --upgrade google-auth google-auth-httplib2 google-auth-oauthlib

ENCODED_QUERY=$(echo $prompt_idea | sed 's/ /%20/g') # URL encoding for spaces
URL="https://www.googleapis.com/customsearch/v1?q=$ENCODED_QUERY&key=$API_KEY"

# Send the request
curl -X GET "$URL"
