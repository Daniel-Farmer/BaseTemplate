#!/bin/bash

# Update the package list
sudo apt update -y -q

# Check if jq is installed and install it if needed
dpkg -l | grep -qw jq || sudo apt install jq -y -q

# Check if Maven is installed and install it if needed
dpkg -l | grep -qw maven || sudo apt install maven -y -q

# Check if Java is installed and install it if needed
dpkg -l | grep -qw openjdk-17-jdk || sudo apt install openjdk-17-jdk -y -q

# Create an example JSON file
cat <<EOF > /root/details.json
{
    "userid": "danielfarmer",
    "projectid": "89422",
    "plugin_name": "ExamplePlugin",
    "prompt": "when the server starts, say hello world"
}
EOF

# Extract variables from the JSON file
project_dir=$(jq -r '.projectid' /root/details.json)
plugin_name=$(jq -r '.plugin_name' /root/details.json)

# Create the project directory and subdirectories
mkdir -p "$project_dir/src/main/java/com/example/plugin"
mkdir -p "$project_dir/src/main/resources"

# Define the BuildTools directory and file
buildtools_dir="/root/BuildTools"
buildtools_file="$buildtools_dir/BuildTools.jar"

# Check if BuildTools.jar already exists
if [ -f "$buildtools_file" ]; then
    echo "BuildTools.jar already exists. Skipping download."
else
    echo "BuildTools.jar not found. Downloading..."
    mkdir -p "$buildtools_dir"
    curl -o "$buildtools_file" https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
fi

# Run BuildTools to compile and install Spigot API in the local Maven repository
cd "$buildtools_dir"
java -jar BuildTools.jar --rev 1.18

# Return to the root directory
cd /root

# Create the main Java class file
cat <<EOF > "$project_dir/src/main/java/com/example/plugin/Main.java"
package com.example.plugin;

import org.bukkit.plugin.java.JavaPlugin;

public class Main extends JavaPlugin {
    @Override
    public void onEnable() {
        // Plugin startup logic
        getLogger().info("$plugin_name enabled!");
    }

    @Override
    public void onDisable() {
        // Plugin shutdown logic
        getLogger().info("$plugin_name disabled!");
    }
}
EOF

# Create the plugin.yml file
cat <<EOF > "$project_dir/src/main/resources/plugin.yml"
name: $plugin_name
version: 1.0
main: com.example.plugin.Main
api-version: 1.18
EOF

# Create the Maven `pom.xml` file
cat <<EOF > "$project_dir/pom.xml"
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>$plugin_name</artifactId>
    <version>1.0</version>
    <packaging>jar</packaging>

    <name>$plugin_name</name>
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
                    <source>\${java.version}</source>
                    <target>\${java.version}</target>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# Compile the plugin using Maven
cd "$project_dir"
mvn clean package

# Remove the installation script
rm -r /root/install.sh

echo "Spigot plugin structure with Maven and BuildTools created and compiled successfully in '$project_dir'."
