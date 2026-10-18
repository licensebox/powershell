#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update
sudo apt-get install -y wget apt-transport-https software-properties-common
wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -O /tmp/licensebox-ms.deb
sudo dpkg -i /tmp/licensebox-ms.deb
sudo apt-get update
sudo apt-get install -y powershell
