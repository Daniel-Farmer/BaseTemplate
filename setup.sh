#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run this script as sudo or root!"
    exit 1
fi

# --- Configuration ---
API_DATA_FILE="api-data.json"
BASE_DIR="/root/BaseTemplate" # Root directory where plugin projects will be placed

# --- Error Handling and Cleanup ---

# Function to clean up the script file itself
cleanup_script() {
    # Check if the script is being run directly before attempting self-delete
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]] && [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
        echo "Cleaning up script file..."
        rm -f "$SCRIPT_PATH"
    fi
}

# Get the script's absolute path early for cleanup
SCRIPT_PATH="$(realpath "$0")"

# Set a trap to call cleanup_script on exit (including errors)
trap cleanup_script EXIT

# --- Prerequisites Check and Installation ---

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install jq with retry logic for apt lock
install_jq_with_retry() {
    echo "'jq' is not installed. Attempting to install it now..."
    MAX_RETRIES=8; WAIT_SECONDS=10; retry_count=0
    while ! command_exists jq && [ $retry_count -lt $MAX_RETRIES ]; do
        retry_count=$((retry_count + 1))
        if fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock >/dev/null 2>&1; then
            echo "APT lock detected (jq install). Waiting ${WAIT_SECONDS}s (retry ${retry_count}/${MAX_RETRIES})..."
            sleep $WAIT_SECONDS; continue
        fi
        echo "Attempting jq installation (retry ${retry_count}/${MAX_RETRIES})..."
        if apt-get update -y >/dev/null 2>&1 && apt-get install -y jq >/dev/null 2>&1; then
            if command_exists jq; then echo "jq installed successfully."; return 0;
            else echo "jq install attempt ${retry_count} finished, but command not found."; fi
        else echo "jq installation attempt ${retry_count} failed."; fi
        if ! command_exists jq && [ $retry_count -lt $MAX_RETRIES ]; then echo "Waiting ${WAIT_SECONDS}s..."; sleep $WAIT_SECONDS; fi
    done
    if command_exists jq; then echo "jq was installed successfully after retries."; return 0;
    else
        echo "-----------------------------------------------------"; echo "ERROR: Failed to install jq after multiple attempts."; echo "-----------------------------------------------------"
        echo "Please install it manually: sudo apt-get update && sudo apt-get install -y jq"; echo "Then re-run the script."; return 1
    fi
}

# Function to install Maven
install_maven() {
    echo "'maven' (mvn command) is not installed. Attempting to install it now..."
    # No complex retry here, assume apt is unlocked after jq install
    if apt-get update -y && apt-get install -y maven; then
        if command_exists mvn; then echo "Maven installed successfully."; return 0;
        else echo "Maven install finished, but 'mvn' command not found."; return 1; fi
    else
        echo "-----------------------------------------------------"; echo "ERROR: Failed to install Maven."; echo "-----------------------------------------------------"
        echo "Please install it manually: sudo apt-get update && sudo apt-get install -y maven"; echo "Then re-run the script."; return 1
    fi
}

# Check and install jq
if ! command_exists jq; then
    if ! install_jq_with_retry; then echo "Script requires 'jq' to proceed. Exiting."; exit 1; fi
else echo "'jq' is already installed."; fi

# Check and install Maven
if ! command_exists mvn; then
    if ! install_maven; then echo "Script requires 'maven' (mvn) to compile the plugin. Exiting."; exit 1; fi
else echo "'maven' (mvn command) is already installed."; fi


# --- JSON Data Reading ---

# Check if the API JSON file exists
if [ ! -f "$API_DATA_FILE" ]; then
    echo "API data file ($API_DATA_FILE) not found! Please ensure it exists in the script's directory."; exit 1
fi

# Extract data using jq, exit on failure or null/empty values
AUTHOR=$(jq -r '.author' "$API_DATA_FILE"); if [ $? -ne 0 ] || [ "$AUTHOR" == "null" ] || [ -z "$AUTHOR" ]; then echo "Failed to read/validate 'author' from $API_DATA_FILE."; exit 1; fi
PLUGIN_NAME=$(jq -r '.plugin_name' "$API_DATA_FILE"); if [ $? -ne 0 ] || [ "$PLUGIN_NAME" == "null" ] || [ -z "$PLUGIN_NAME" ]; then echo "Failed to read/validate 'plugin_name' from $API_DATA_FILE."; exit 1; fi
VERSION=$(jq -r '.version' "$API_DATA_FILE"); if [ $? -ne 0 ] || [ "$VERSION" == "null" ] || [ -z "$VERSION" ]; then echo "Failed to read/validate 'version' from $API_DATA_FILE."; exit 1; fi

echo "Read from $API_DATA_FILE: Plugin=$PLUGIN_NAME, Author=$AUTHOR, Version=$VERSION"

# --- Directory Structure Creation ---

PLUGIN_DIR="$BASE_DIR/$PLUGIN_NAME" # Specific directory for this plugin project

# Remove any prior project directory to ensure a clean setup
if [ -d "$PLUGIN_DIR" ]; then
    echo "Cleaning up existing project directory $PLUGIN_DIR..."
    if ! rm -rf "$PLUGIN_DIR"; then echo "Failed to remove existing directory $PLUGIN_DIR."; exit 1; fi
fi

# Create the main project directory structure
echo "Setting up project structure at $PLUGIN_DIR..."
AUTH_LOWER=$(echo "$AUTHOR" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g'); [ -z "$AUTH_LOWER" ] && AUTH_LOWER="unknownauthor"
PLUGIN_LOWER=$(echo "$PLUGIN_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g'); [ -z "$PLUGIN_LOWER" ] && PLUGIN_LOWER="unknownplugin"

JAVA_PKG_PATH="com/${AUTH_LOWER}/${PLUGIN_LOWER}"
JAVA_SRC_DIR="$PLUGIN_DIR/src/main/java/$(echo $JAVA_PKG_PATH | tr . /)"
RESOURCES_DIR="$PLUGIN_DIR/src/main/resources"

if ! mkdir -p "$JAVA_SRC_DIR"; then echo "Failed to create source directory: $JAVA_SRC_DIR"; exit 1; fi
if ! mkdir -p "$RESOURCES_DIR"; then echo "Failed to create resources directory: $RESOURCES_DIR"; exit 1; fi

echo "Directory structure created successfully."

# --- File Generation ---

# Write the plugin.yml file
PLUGIN_YML_FILE="$RESOURCES_DIR/plugin.yml"
echo "Creating $PLUGIN_YML_FILE..."
cat <<EOL > "$PLUGIN_YML_FILE"
name: ${PLUGIN_NAME}
version: ${VERSION}
description: A Minecraft Spigot plugin created by ${AUTHOR}.
author: ${AUTHOR}
main: ${JAVA_PKG_PATH}.Main
api-version: 1.18 # Adjust as needed
EOL
echo "Created plugin.yml"

# Write the Main.java file (with enhanced enable message)
MAIN_CLASS_FILE="$JAVA_SRC_DIR/Main.java"
echo "Creating $MAIN_CLASS_FILE..."
cat <<EOL > "$MAIN_CLASS_FILE"
package ${JAVA_PKG_PATH};

import org.bukkit.plugin.java.JavaPlugin;
// Removed explicit Logger import, using getLogger() is standard

public class Main extends JavaPlugin {

    @Override
    public void onEnable() {
        // Plugin startup logic - Use the plugin's logger
        getLogger().info("==================================================");
        getLogger().info(" ${getDescription().getName()} v${getDescription().getVersion()} by ${getDescription().getAuthors().get(0)}"); // Use plugin.yml data
        getLogger().info(" Hello World! The plugin has been enabled successfully.");
        getLogger().info("==================================================");

        // Example: Register commands/listeners here
        // getServer().getPluginManager().registerEvents(new MyListener(), this);
        // getCommand("mycommand").setExecutor(new MyCommandExecutor());
    }

    @Override
    public void onDisable() {
        // Plugin shutdown logic
        getLogger().info("${getDescription().getName()} has been disabled.");
    }
}
EOL
echo "Created Main.java"

# Write the pom.xml file
POM_XML_FILE="$PLUGIN_DIR/pom.xml" # POM should be in the project root ($PLUGIN_DIR)
echo "Creating $POM_XML_FILE..."
cat <<EOL > "$POM_XML_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.${AUTH_LOWER}</groupId>
    <artifactId>${PLUGIN_LOWER}</artifactId> <!-- Use lowercase artifactId -->
    <version>${VERSION}</version>
    <packaging>jar</packaging>

    <name>${PLUGIN_NAME}</name>
    <description>A Minecraft Spigot plugin created by ${AUTHOR}.</description>
    <!-- <url>Your project URL</url> -->

    <properties>
        <java.version>1.8</java.version> <!-- Or 11, 16, 17 depending on Spigot target -->
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <build>
        <defaultGoal>clean package</defaultGoal> <!-- Optional: Default goal -->
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.10.1</version> <!-- Use a recent version -->
                <configuration>
                    <source>\${java.version}</source>
                    <target>\${java.version}</target>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-shade-plugin</artifactId>
                <version>3.3.0</version> <!-- Use a recent version -->
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>shade</goal>
                        </goals>
                        <configuration>
                             <!-- Optional: minimize jar size -->
                            <minimizeJar>true</minimizeJar>
                             <!-- Optional: relocate dependencies if needed -->
                            <!--
                            <relocations>
                                <relocation>
                                    <pattern>com.example.dependency</pattern>
                                    <shadedPattern>\${project.groupId}.shaded.dependency</shadedPattern>
                                </relocation>
                            </relocations>
                            -->
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
        <resources>
            <resource>
                <directory>src/main/resources</directory>
                <filtering>true</filtering> <!-- Enable filtering for plugin.yml -->
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
        <!-- Add other repositories if needed (e.g., PaperMC) -->
        <!--
        <repository>
            <id>papermc-repo</id>
            <url>https://repo.papermc.io/repository/maven-public/</url>
        </repository>
        -->
    </repositories>

    <dependencies>
        <!-- Spigot API - Make sure the version matches your target server -->
        <dependency>
            <groupId>org.spigotmc</groupId>
            <artifactId>spigot-api</artifactId>
            <version>1.18.2-R0.1-SNAPSHOT</version> <!-- Example: 1.18.2 - CHANGE AS NEEDED -->
            <scope>provided</scope>
        </dependency>
        <!-- Add other dependencies here -->
    </dependencies>
</project>
EOL
echo "Created pom.xml"

# --- Maven Compilation ---
echo "----------------------------------------"
echo "Attempting to compile the plugin using Maven..."
echo "----------------------------------------"

# Use pushd/popd to manage directory changes safely
if pushd "$PLUGIN_DIR" > /dev/null; then
    # Define JAR path here for later use
    JAR_NAME="${PLUGIN_LOWER}-${VERSION}.jar"
    JAR_PATH="target/${JAR_NAME}"

    # Run Maven clean package - hide excessive output unless error
    if mvn clean package -B; then # -B runs in batch mode (less verbose)
        echo "----------------------------------------"
        echo "Maven build successful!"
        if [ -f "$JAR_PATH" ]; then
            echo "Plugin JAR created at: $PLUGIN_DIR/$JAR_PATH"
        else
            echo "WARNING: Maven reported success, but expected JAR file not found at $JAR_PATH"
            # Try finding any jar in target in case filename slightly differs
            FALLBACK_JAR=$(find target -maxdepth 1 -name '*.jar' -print -quit)
            if [ -n "$FALLBACK_JAR" ] && [ -f "$FALLBACK_JAR" ]; then
                echo "Found alternative JAR: $PLUGIN_DIR/$FALLBACK_JAR"
                JAR_PATH="$FALLBACK_JAR" # Update JAR_PATH if found
            fi
        fi
        echo "----------------------------------------"
    else
        echo "----------------------------------------"
        echo "ERROR: Maven build failed. See output above for details."
        echo "You may need to check the pom.xml or Java code for errors."
        echo "----------------------------------------"
        popd > /dev/null # Ensure we pop back even on failure
        exit 1 # Exit if build fails
    fi
    popd > /dev/null # Pop back to original directory
else
    echo "ERROR: Failed to change directory to $PLUGIN_DIR to run Maven."
    exit 1
fi


# Final message
echo ""
echo "Spigot plugin project '$PLUGIN_NAME' created and compiled successfully!"
echo "Project Location: $PLUGIN_DIR"
# Ensure JAR_PATH is set, provide a default message if not (though build should fail if it's not)
if [ -n "$JAR_PATH" ] && [ -f "$PLUGIN_DIR/$JAR_PATH" ]; then
    echo "Runnable Jar: $PLUGIN_DIR/$JAR_PATH"
else
     echo "Runnable Jar: (Build may have failed or JAR not found in target directory)"
fi

# Script will now exit, and the trap will call cleanup_script.
