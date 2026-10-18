$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot ../Licensebox.psd1)
Test-ModuleManifest (Join-Path $PSScriptRoot ../Licensebox.psd1) | Out-Null
if((ConvertTo-LicenseboxBinding demo linux-machine-id "12345678123456789abc1234567890ab`0") -notlike 'm1:*'){throw 'derive'}
try {$null=Test-LicenseboxLease bad demo @{} 0;throw 'accepted'}catch{$e=$_.Exception;while($e.InnerException){$e=$e.InnerException};if($e.Code -ne 'malformed'){throw}}
'PowerShell binding checks passed'
$dir=[System.IO.Directory]::CreateTempSubdirectory('licensebox-powershell-').FullName
$c=New-LicenseboxClient demo @{'test-key'='A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg'} -Directory $dir -MachineBinding {throw 'synthetic callback failure'}
try {try {$null=Connect-Licensebox $c -Timeout .1;throw 'callback failure ignored'}catch{$e=$_.Exception;while($e.InnerException){$e=$e.InnerException};if($e.Code -ne 'callback_error'){throw}}}finally{Close-LicenseboxClient $c;Close-LicenseboxClient $c;Remove-Item -Recurse -Force $dir}
