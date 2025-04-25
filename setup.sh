#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as sudo or root!"
    exit 1
fi

# --- Configuration ---
API_DATA_FILE="api-data.json"
BASE_DIR="/root/BaseTemplate" # As mentioned in the README

# --- Error Handling and Cleanup ---

# Function to clean up the script file itself
cleanup_script() {
    # Check if the script is being run directly (e.g., not sourced) before attempting self-delete
    # Also check if the script path variable is set
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
        echo "Cleaning up script file..."
        rm -f "$SCRIPT_PATH"
        # Optional: Attempt to remove potential leftover apt lock files (use with caution)
        # This is a safeguard, proper apt usage shouldn't leave locks
        # sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock # Uncomment if needed, but risky
    fi
}

# Get the script's absolute path early for cleanup
SCRIPT_PATH="$(realpath "$0")"

# Set a trap to call cleanup_script on exit (including errors)
# Note: EXIT trap runs regardless of exit status (0 or non-zero)
trap cleanup_script EXIT

# --- Prerequisites Check and Installation (jq) ---

# Function to check if jq is installed
check_jq() {
    command -v jq >/dev/null 2>&1
}

# Function to install jq with retry logic for apt lock
install_jq_with_retry() {
    echo "'jq' is not installed. Attempting to install it now..."

    MAX_RETRIES=8         # Maximum number of installation attempts
    WAIT_SECONDS=10       # Seconds to wait between retries or when lock is found
    retry_count=0

    while ! check_jq && [ $retry_count -lt $MAX_RETRIES ]; do
        retry_count=$((retry_count + 1)) # Increment retry count

        # --- Check for APT lock ---
        # Use fuser to see if any process is using the lock files
        if fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock >/dev/null 2>&1; then
            echo "APT lock detected. Waiting ${WAIT_SECONDS} seconds before retry ${retry_count}/${MAX_RETRIES}..."
            sleep $WAIT_SECONDS
            continue # Skip installation attempt, just wait and re-check
        fi

        # --- Attempt Installation ---
        echo "Attempting jq installation (retry ${retry_count}/${MAX_RETRIES})..."
        # Redirect stdout and stderr to /dev/null to keep install output clean unless failure
        # We rely on the exit code and then check if jq is actually installed
        if apt-get update -y >/dev/null 2>&1 && apt-get install -y jq >/dev/null 2>&1; then
            # Check specifically if jq was installed *after* the attempt
            if check_jq; then
                 echo "jq installed successfully."
                 return 0 # Success
            else
                 echo "jq installation attempt ${retry_count}/${MAX_RETRIES} finished, but jq command not found."
            fi
        else
            # This branch is reached if apt-get install returned non-zero
            echo "jq installation attempt ${retry_count}/${MAX_RETRIES} failed."
        fi

        # If not successful and not last retry, wait before the next attempt
        if ! check_jq && [ $retry_count -lt $MAX_RETRIES ]; then
             echo "Waiting ${WAIT_SECONDS} seconds before next attempt..."
             sleep $WAIT_SECONDS
        fi
    done

    # --- Final Check and Error Reporting ---
    if check_jq; then
        echo "jq was installed successfully after retries."
        return 0
    else
        echo "-----------------------------------------------------"
        echo "ERROR: Failed to install jq after multiple attempts."
        echo "-----------------------------------------------------"
        echo "Please install it manually and re-run the script:"
        echo "  sudo apt-get update && sudo apt-get install -y jq"
        echo ""
        echo "If you still see 'Could not get lock' errors, another process is using the package manager."
        echo "You can try to identify the process:"
        echo "  sudo lsof /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock"
        echo "-----------------------------------------------------"
        return 1 # Failure
    fi
}

# Check and install jq
if ! check_jq; then
    if ! install_jq_with_retry; then
        echo "Script requires 'jq' to proceed. Exiting."
        # The trap EXIT will run cleanup_script automatically
        exit 1
    fi
else
    echo "'jq' is already installed."
fi

# --- JSON Data Reading ---

# Check if the API JSON file exists
if [ ! -f "$API_DATA_FILE" ]; then
    echo "API data file ($API_DATA_FILE) not found! Please ensure it exists in the script's directory."
    # The trap EXIT will run cleanup_script automatically
    exit 1
fi

# Extract data from JSON using 'jq'
# Use explicit checks for jq output being non-null or empty string
AUTHOR=$(jq -r '.author' "$API_DATA_FILE")
if [ $? -ne 0 ] || [ "$AUTHOR" == "null" ] || [ -z "$AUTHOR" ]; then
    echo "Failed to read or validate 'author' from $API_DATA_FILE. Is the JSON valid and field present?"
    exit 1
fi

PLUGIN_NAME=$(jq -r '.plugin_name' "$API_DATA_FILE")
if [ $? -ne 0 ] || [ "$PLUGIN_NAME" == "null" ] || [ -z "$PLUGIN_NAME" ]; then
    echo "Failed to read or validate 'plugin_name' from $API_DATA_FILE. Is the JSON valid and field present?"
    exit 1
fi

VERSION=$(jq -r '.version' "$API_DATA_FILE")
if [ $? -ne 0 ] || [ "$VERSION" == "null" ] || [ -z "$VERSION" ]; then
    echo "Failed to read or validate 'version' from $API_DATA_FILE. Is the JSON valid and field present?"
    exit 1
fi

echo "Read from $API_DATA_FILE:"
echo "  Plugin Name: $PLUGIN_NAME"
echo "  Author: $AUTHOR"
echo "  Version: $VERSION"

# --- Directory Structure Creation ---

# Remove any prior files or directories to ensure a clean setup
if [ -d "$BASE_DIR" ]; then
    echo "Cleaning up existing directory $BASE_DIR..."
    if ! rm -rf "$BASE_DIR"; then
        echo "Failed to remove existing directory $BASE_DIR. Please remove it manually."
        exit 1 # Exit if cleanup of previous run failed
    fi
fi

# Create the main project directory structure
echo "Setting up project structure at $BASE_DIR..."
# Using lowercase author and plugin name for package path as is standard practice
AUTH_LOWER=$(echo "$AUTHOR" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
PLUGIN_LOWER=$(echo "$PLUGIN_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')

# Basic check to prevent empty package paths if author/plugin name were weird
if [ -z "$AUTH_LOWER" ]; then AUTH_LOWER="unknownauthor"; fi
if [ -z "$PLUGIN_LOWER" ]; then PLUGIN_LOWER="unknownplugin"; fi


JAVA_SRC_DIR="$BASE_DIR/src/main/java/com/$AUTH_LOWER/$PLUGIN_LOWER"
RESOURCES_DIR="$BASE_DIR/src/main/resources"

if ! mkdir -p "$JAVA_SRC_DIR"; then
    echo "Failed to create source directory: $JAVA_SRC_DIR"
    exit 1
fi
if ! mkdir -p "$RESOURCES_DIR"; then
    echo "Failed to create resources directory: $RESOURCES_DIR"
    exit 1
fi

echo "Directory structure created successfully."

# --- File Generation (Basic Examples) ---

# Write the plugin.yml file
PLUGIN_YML_FILE="$RESOURCES_DIR/plugin.yml"
echo "Creating $PLUGIN_YML_FILE..."
cat <<EOL > "$PLUGIN_YML_FILE"
name: $PLUGIN_NAME
version: $VERSION
description: A Minecraft Spigot plugin.
author: $AUTHOR
main: com.${AUTH_LOWER}.${PLUGIN_LOWER}.Main
api-version: 1.18 # You might want to adjust this based on your target server version
EOL
echo "Created plugin.yml"

# Write the Main.java file
MAIN_CLASS_FILE="$JAVA_SRC_DIR/Main.java"
echo "Creating $MAIN_CLASS_FILE..."
cat <<EOL > "$MAIN_CLASS_FILE"
package com.${AUTH_LOWER}.${PLUGIN_LOWER};

import org.bukkit.plugin.java.JavaPlugin;
import java.util.logging.Logger; // Import Logger

public class Main extends JavaPlugin {

    private static final Logger log = Logger.getLogger("Minecraft"); // Get server logger

    @Override
    public void onEnable() {
        // Plugin startup logic
        log.info("$PLUGIN_NAME v$VERSION by $AUTHOR has been enabled!");
        // Or use the plugin's logger: getLogger().info("$PLUGIN_NAME v$VERSION by $AUTHOR has been enabled!");

        // Example: Register a simple command or event listener
        // getServer().getPluginManager().registerEvents(new MyEventListener(), this);
        // getCommand("mycommand").setExecutor(new MyCommandExecutor());
    }

    @Override
    public void onDisable() {
        // Plugin shutdown logic
        log.info("$PLUGIN_NAME has been disabled.");
        // Or use the plugin's logger: getLogger().info("$PLUGIN_NAME has been disabled.");
    }
}
EOL
echo "Created Main.java"

# Add a basic pom.xml for Maven if desired (based on README mention of essential files)
# This was in my reconstruction but not your provided script. Adding it here
# as it's standard for Spigot plugins and aligns with "essential files".
POM_XML_FILE="$BASE_DIR/pom.xml"
echo "Creating $POM_XML_FILE..."
cat <<EOL > "$POM_XML_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.${AUTH_LOWER}</groupId>
    <artifactId>${PLUGIN_LOWER}</artifactId>
    <version>${VERSION}</version>
    <packaging>jar</packaging>

    <name>${PLUGIN_NAME}</name>
    <description>A Minecraft Spigot plugin.</description>
    <!-- <url>https://github.com/${AUTHOR}/${PLUGIN_NAME}</url> --> # Example URL, uncomment and replace if needed

    <properties>
        <java.version>1.8</java.version> # Adjust based on your needs and Spigot version
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.8.1</version> # Use a recent version
                <configuration>
                    <source>${java.version}</source>
                    <target>${java.version}</target>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-shade-plugin</artifactId>
                <version>3.2.4</version> # Use a recent version
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>shade</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
        <resources>
            <resource>
                <directory>src/main/resources</directory>
                <includes>
                    <include>**/*.yml</include>
                </includes>
            </resource>
        </resources>
    </build>

    <repositories>
        <repository>
            <id>spigotmc-repo</id>
            <url>https://hub.spigotmc.org/nexus/content/repositories/snapshots/</url>
        </repository>
        <repository>
            <id>sonatype</id>
            <url>https://oss.sonatype.org/content/groups/public/</url>
        </repository>
    </repositories>

    <dependencies>
        <!--Spigot API-->
        <!--Adjust version based on your needs. Example for 1.16.5-R0.1-SNAPSHOT: -->
        <dependency>
            <groupId>org.spigotmc</groupId>
            <artifactId>spigot-api</artifactId>
            <version>1.16.5-R0.1-SNAPSHOT</version> # Change this to your target version (e.g. 1.18.2-R0.1-SNAPSHOT)
            <scope>provided</scope>
        </dependency>
    </dependencies>
</project>
EOL
echo "Created pom.xml"


# Final message
echo "Spigot plugin project structure created successfully at $BASE_DIR!"

# The script will now exit, and the trap will call cleanup_script automatically.
