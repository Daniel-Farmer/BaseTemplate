#!/bin/bash

# Create the main project directory structure
mkdir -p BaseTemplate/src/main/java/com/yourname/myplugin
mkdir -p BaseTemplate/src/main/resources

# Write the plugin.yml file
cat <<EOL > BaseTemplate/src/main/resources/plugin.yml
name: BaseTemplate
version: 1.0
main: com.yourname.myplugin.Main
api-version: 1.18
EOL

# Write the Main.java file
cat <<EOL > BaseTemplate/src/main/java/com/yourname/myplugin/Main.java
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

# Write the README.md file
cat <<EOL > BaseTemplate/README.md
# BaseTemplate

This repository contains the setup for a Minecraft plugin using the Spigot API.

## Project Structure
- **src/main/resources/plugin.yml**: The configuration file for the plugin.
- **src/main/java/com/yourname/myplugin/Main.java**: The main class for the plugin.

## How to Use
1.
