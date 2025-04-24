#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as sudo or root!"
    exit 1
fi

# Define the base project directory
BASE_DIR="/root/BaseTemplate"

# Remove any prior files or directories to ensure a clean setup
if [ -d "$BASE_DIR" ]; then
    echo "Cleaning up existing files..."
    rm -rf "$BASE_DIR"
fi

# Create the main project directory structure
echo "Setting up project structure..."
mkdir -p "$BASE_DIR/src/main/java/com/yourname/myplugin"
mkdir -p "$BASE_DIR/src/main/resources"

# Write the plugin.yml file
cat <<EOL > "$BASE_DIR/src/main/resources/plugin.yml"
name: BaseTemplate
version: 1.0
main: com.yourname.myplugin.Main
api-version: 1.18
EOL
echo "Created plugin.yml"

# Write the Main.java file
cat <<EOL > "$BASE_DIR/src/main/java/com/yourname/myplugin/Main.java"
package com.yourname.myplugin;

import org.bukkit.plugin.java.JavaPlugin;

public class Main extends JavaPlugin {
    @Override
    public void onEnable() {
        getLogger().info("BaseTemplate has been enabled!");
    }

    @Override
    public void onDisable() {
        getLogger().info("BaseTemplate has been disabled!");
    }
}
EOL
echo "Created Main.java"

# Write the README.md file
cat <<EOL > "$BASE_DIR/README.md"
# BaseTemplate

This repository contains the setup for a Minecraft plugin using the Spigot API.

## Project Structure
- **src/main/resources/plugin.yml**: The configuration file for the plugin.
- **src/main/java/com/yourname/myplugin/Main.java**: The main class for the plugin.

## How to Use
1. Modify the \`Main.java\` and \`plugin.yml\` files as needed.
2. Compile the project into a JAR file.
3. Place the JAR file into the \`plugins\` folder of your Spigot Minecraft server.

Happy coding!
EOL
echo "Created README.md"

# Remove the script itself after execution
SCRIPT_PATH=$(realpath "$0")
echo "Cleaning up setup script..."
rm -f "$SCRIPT_PATH"

# Final message
echo "Spigot plugin project structure created successfully at $BASE_DIR!"
