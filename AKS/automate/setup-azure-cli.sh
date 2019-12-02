#!/bin/bash
echo "Updating system..."
sudo apt-get update
sudo apt-get upgrade
 
echo "Installing AzureCLI"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
