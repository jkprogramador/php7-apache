
# My Set Up with PHP 7.4/Apache/Docker

## Set Up Xdebug/VS Code/Docker

1. Install PHP Debug (published by Xdebug)
2. Through the *Add Configuration...* option in the *Run and Debug* tab, a *launch.json* will be created inside the *.vscode* folder
3. Amend *launch.json* with the following:

        "version": "0.2.0",
        "configurations": [
            {
                "name": "Listen for Xdebug",
                "type": "php",
                "request": "launch",
                "port": 9003,
                "pathMappings": {
                    "/var/www/mydomain/public": "${workspaceRoot}/www/public"
                }
            },