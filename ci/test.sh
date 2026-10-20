#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
pwsh -NoProfile -NonInteractive -File tests/binding_test.ps1
rm -rf build/package/Licensebox
mkdir -p build/package/Licensebox/0.3.0/src
cp Licensebox.psm1 Licensebox.psd1 LICENSE README.md build/package/Licensebox/0.3.0/
cp src/Native.cs build/package/Licensebox/0.3.0/src/
tar -czf build/licensebox-powershell-0.3.0.tar.gz -C build/package Licensebox
PSModulePath="$PWD/build/package${PSModulePath:+:$PSModulePath}" pwsh -NoProfile -NonInteractive -Command 'Import-Module Licensebox; if((Get-LicenseboxBinding demo) -notlike "m1:*"){throw "package consumer failed"}'
