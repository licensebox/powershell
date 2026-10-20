#!/usr/bin/env bash
set -euo pipefail
# The Ubuntu 26.04 runner image ships PowerShell 7.6; install it only where it
# is missing, from Microsoft's repository for this Ubuntu release.
if command -v pwsh >/dev/null; then
 pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
 exit 0
fi
sudo apt-get update
sudo apt-get install -y wget apt-transport-https software-properties-common
. /etc/os-release
wget -q "https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb" -O /tmp/licensebox-ms.deb
sudo dpkg --force-confnew -i /tmp/licensebox-ms.deb
sudo apt-get update
sudo apt-get install -y powershell
