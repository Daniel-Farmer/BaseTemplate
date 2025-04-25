#!/bin/bash

# Prompt the user for an API key
read -p "Please enter your valid API Key: " api_key

# Prompt the user for a plugin idea
read -p "Please enter a plugin idea: " plugin_idea

# Create the JSON file with the provided API key and plugin idea
cat <<EOF > /root/details.json
{
    "userid": "danielfarmer",
    "projectid": "89422",
    "plugin_name": "ExamplePlugin",
    "prompt": "$plugin_idea",
    "apikey": "$api_key"
}
EOF

# Update the package list
sudo apt update -y -q

# Check if jq is installed and install it if needed
dpkg -l | grep -qw jq || sudo apt install jq -y -q

# Check if Maven is installed and install it if needed
dpkg -l | grep -qw maven || sudo apt install maven -y -q

# Check if Java is installed and install it if needed
dpkg -l | grep -qw openjdk-17-jdk || sudo apt install openjdk-17-jdk -y -q

# Install Python 3 and pip if not already installed
dpkg -l | grep -qw python3 || sudo apt install python3 -y -q
dpkg -l | grep -qw python3-pip || sudo apt install python3-pip -y -q

# Install the Google API client library using pip
python3 -m pip install --upgrade google-api-python-client
python3 -m pip install --upgrade google-auth google-auth-httplib2 google-auth-oauthlib

# Extract variables from the JSON file
project_dir=$(jq -r '.projectid' /root/details.json)
plugin_name=$(jq -r '.plugin_name' /root/details.json)
prompt=$(jq -r '.prompt' /root/details.json)
api_key=$(jq -r '.apikey' /root/details.json)

# Create the project directory and subdirectories
mkdir -p "$project_dir/src/main/java/com/example/plugin"
mkdir -p "$project_dir/src/main/resources"

# Get initial file contents
main_java_content=$(cat <<'EOF'
package com.example.plugin;

import org.bukkit.plugin.java.JavaPlugin;

public class Main extends JavaPlugin {
    @Override
    public void onEnable() {
        // Plugin startup logic
    }

    @Override
    public void onDisable() {
        // Plugin shutdown logic
    }
}
EOF
)

plugin_yml_content=$(cat <<'EOF'
name: ExamplePlugin
version: 1.0
main: com.example.plugin.Main
api-version: 1.18
EOF
)

pom_xml_content=$(cat <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://www.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.example</groupId>
    <artifactId>ExamplePlugin</artifactId>
    <version>1.0</version>
    <packaging>jar</packaging>
    <name>ExamplePlugin</name>
    <description>A Minecraft Spigot Plugin</description>
    <properties>
        <java.version>17</java.version>
    </properties>
    <dependencies>
        <dependency>
            <groupId>org.spigotmc</groupId>
            <artifactId>spigot-api</artifactId>
            <version>1.18-R0.1-SNAPSHOT</version>
            <scope>provided</scope>
        </dependency>
    </dependencies>
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.8.1</version>
                <configuration>
                    <source>${java.version}</source>
                    <target>${java.version}</target>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF
)

# Prepare API payload
api_payload=$(jq -n --arg framework "Minecraft Spigot Plugin" \
                     --arg spigot_version "1.18" \
                     --arg description "Use the context from the prompt to make a functional Minecraft Spigot plugin." \
                     --arg prompt "$prompt" \
                     --arg main_java "$main_java_content" \
                     --arg plugin_yml "$plugin_yml_content" \
                     --arg pom_xml "$pom_xml_content" \
                     '{
                         framework: $framework,
                         spigot_version: $spigot_version,
                         description: $description,
                         prompt: $prompt,
                         files: {
                             "Main.java": $main_java,
                             "plugin.yml": $plugin_yml,
                             "pom.xml": $pom_xml
                         }
                     }')

# Send the API request to Google
response=$(curl -s -X POST \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d "$api_payload" \
    https://example.googleapis.com/v1/code-gen)

# Validate API response
if [ -z "$response" ] || ! echo "$response" | jq . > /dev/null 2>&1; then
    echo "Error: Invalid response from API."
    exit 1
fi

# Parse JSON response
new_main_java=$(echo "$response" | jq -r '.["main.java"]')
new_plugin_yml=$(echo "$response" | jq -r '.["plugin.yml"]')
new_pom_xml=$(echo "$response" | jq -r '.["pom.xml"]')

# Handle empty or malformed responses
if [ -z "$new_main_java" ] || [ "$new_main_java" == "null" ]; then
    new_main_java="$main_java_content"
fi
if [ -z "$new_plugin_yml" ] || [ "$new_plugin_yml" == "null" ]; then
    new_plugin_yml="$plugin_yml_content"
fi
if [ -z "$new_pom_xml" ] || [ "$new_pom_xml" == "null" ]; then
    new_pom_xml="$pom_xml_content"
fi

# Update the project files
echo "$new_main_java" > "$project_dir/src/main/java/com/example/plugin/Main.java"
echo "$new_plugin_yml" > "$project_dir/src/main/resources/plugin.yml"
echo "$new_pom_xml" > "$project_dir/pom.xml"

# Compile the plugin using Maven
cd "$project_dir"
mvn clean package
