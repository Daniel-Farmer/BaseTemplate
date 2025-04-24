# BaseTemplate
A streamlined Bash script designed to set up the directory structure and essential files for a Minecraft Spigot plugin.
## Features
- Dynamically creates a Spigot plugin directory structure based on API-provided data.
- Reads configuration from a JSON file (`api-data.json`) for customization.
- Automatically installs dependencies (`jq`) if missing.
- Includes robust error handling and cleanup.
## Prerequisites
- Ensure the `api-data.json` file is placed in the same directory as the script before execution.
- Example `api-data.json` content: ```
  {
    "author": "DanielFarmer",
    "plugin_name": "CustomPlugin",
    "version": "1.0"
  }```
## Quick Start
To download, set up, and execute the script in a single command:
```
curl -O https://raw.githubusercontent.com/Daniel-Farmer/BaseTemplate/main/setup.sh && chmod +x setup.sh && sudo bash setup.sh
```
## Notes
- The script cleans itself up after execution.
- The plugin directory will be created in `/root/BaseTemplate`.
- Customize the `api-data.json` file to fit your requirements.
- ## Troubleshooting
- If `jq` fails to install automatically, run:
  ```bash
  sudo apt-get update && sudo apt-get install -y jq
  ```
  Then re-run the script.
