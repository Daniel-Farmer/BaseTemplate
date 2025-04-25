#!/bin/bash

# Update the package list
sudo apt update -y -q

# Check if jq is installed and install it if needed
dpkg -l | grep -qw jq || sudo apt install jq -y -q

# Create the project directory and subdirectories
project_dir=$(jq -r '.projectid' /root/details.json)
mkdir -p "$project_dir/src"

# Create an example JSON file
cat <<EOF > /root/details.json
{
    "userid": "danielfarmer",
    "projectid": "89422",
    "plugin_name": "ExamplePlugin",
    "prompt": "when the server starts, say hello world"
}
EOF

# Create the main Java class file
plugin_name=$(jq -r '.plugin_name' /root/details.json)
cat <<EOF > "$project_dir/src/Main.java"
package $project_dir;

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
cat <<EOF > "$project_dir/plugin.yml"
name: $plugin_name
version: 1.0
main: $project_dir.Main
api-version: 1.18
EOF

# Remove the installation script
rm -r install.sh

echo "Spigot plugin structure created successfully in '$project_dir'."
#!/bin/bash

# Update the package list
sudo apt update -y -q

# Check if jq is installed and install it if needed
dpkg -l | grep -qw jq || sudo apt install jq -y -q

# Create the project directory and subdirectories
project_dir=$(jq -r '.projectid' /root/details.json)
mkdir -p "$project_dir/src"

# Create an example JSON file
cat <<EOF > /root/details.json
{
    "userid": "danielfarmer",
    "projectid": "89422",
    "plugin_name": "ExamplePlugin",
    "prompt": "when the server starts, say hello world"
}
EOF

# Create the main Java class file
plugin_name=$(jq -r '.plugin_name' /root/details.json)
cat <<EOF > "$project_dir/src/Main.java"
package $project_dir;

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
cat <<EOF > "$project_dir/plugin.yml"
name: $plugin_name
version: 1.0
main: $project_dir.Main
api-version: 1.18
EOF

# Remove the installation script
rm -r install.sh

echo "Spigot plugin structure created successfully in '$project_dir'."
