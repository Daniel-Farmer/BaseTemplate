#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as sudo or root!"
    exit 1
fi

# Install 'jq' if it's not installed
if ! command -v jq &>/dev/null; then
    echo "'jq' is not installed. Installing it now..."
    apt-get update && apt-get install -y jq
    if [ $? -ne 0 ]; then
        echo "Failed to install jq. Please install it manually and re-run the script."
        exit 1
    fi
else
    echo "'jq' is already installed."
fi

# Define the base project directory
BASE_DIR="/root/BaseTemplate"

# Check if the API JSON file exists
API_FILE="api-data.json"
if [ ! -f "$API_FILE" ]; then
    echo "API data file ($API_FILE) not found! Please ensure it exists."
    exit 1
fi

# Extract data from JSON using 'jq'
AUTHOR=$(jq -r '.author' "$API_FILE")
PLUGIN_NAME=$(jq -r '.plugin_name' "$API_FILE")
VERSION=$(jq -r '.version' "$API_FILE")

# Validate required fields
if [ -z "$AUTHOR" ] || [ -z "$PLUGIN_NAME" ] || [ -z "$VERSION" ]; then
    echo "Invalid API data! Ensure all fields (author, plugin_name, version) are provided."
    exit 1
fi

# Remove any prior files or directories to ensure a clean setup
if [ -d "$BASE_DIR" ]; then
    echo "Cleaning up existing files..."
    rm -rf "$BASE_DIR"
fi

# Create the main project directory structure
echo "Setting up project structure..."
mkdir -p "$BASE_DIR/src/main/java/com/$AUTHOR/$PLUGIN_NAME"
mkdir -p "$BASE_DIR/src/main/resources"

# Write the plugin.yml file
cat <<EOL > "$BASE_DIR/src/main/resources/plugin.yml"
name: $PLUGIN_NAME
version: $VERSION
main: com.$AUTHOR.$PLUGIN_NAME.Main
api-version: 1.18
EOL
echo "Created plugin.yml"

# Write the Main.java file
cat <<EOL > "$BASE_DIR/src/main/java/com/$AUTHOR/$PLUGIN_NAME/Main.java"
package com.$AUTHOR.$PLUGIN_NAME;

import org.bukkit.plugin.java.JavaPlugin;

public class Main extends JavaPlugin {
    @Override
    public void onEnable() {
        getLogger().info("$PLUGIN_NAME has been enabled!");
    }

    @Override
    public void onDisable() {
        getLogger().info("$PLUGIN_NAME has been disabled!");
    }
}
EOL
echo "Created Main.java"

# Remove the script itself after execution
SCRIPT_PATH=$(realpath "$0")
echo "Cleaning up setup script..."
rm -f "$SCRIPT_PATH"

# Final message
echo "Spigot plugin project structure created successfully at $BASE_DIR!"
