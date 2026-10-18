$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot ../Licensebox.psd1)
$r=ConvertFrom-Json -AsHashtable ([Console]::In.ReadToEnd())
function Run-Adapter {
 switch($r.op){
  derive {return ConvertTo-LicenseboxBinding -Product $r.product -Source $r.source -RawId $r.raw_id}
  native {return Get-LicenseboxBinding -Product $r.product}
  verify {return Test-LicenseboxLease -Token $r.token -Product $r.product -Keys $r.keys -Now $r.now}
 }
 $clockValue=[double]$r.now;$bindingValue=[string]$r.binding
 $clock={return $clockValue}.GetNewClosure();$binding={return $bindingValue}.GetNewClosure()
 $extra=@{};if($r.ContainsKey('ca_bundle')){$extra['CaBundle']=$r.ca_bundle}
 $c=New-LicenseboxClient -Product $r.product -Keys $r.keys -Version conformance -Server $r.server -Directory $r.directory -Clock $clock -MachineBinding $binding -OnSignIn {param($u,$code)} @extra
 try {
  switch($r.op){
   lease {Get-LicenseboxLease $c}
   status {Get-LicenseboxStatus $c}
   sign_in {Connect-Licensebox $c -Timeout 3}
   require {$module='core';if($r.ContainsKey('module')){$module=$r.module};Assert-LicenseboxModule $c $module}
   repeat {$null=Assert-LicenseboxModule $c core;Assert-LicenseboxModule $c core}
   logout {Disconnect-Licensebox $c;return $null}
   modules {Get-LicenseboxModule $c}
   requests {Get-LicenseboxRequest $c}
   request {Request-LicenseboxAccess $c @('export') 'café – test'}
   access-link {Get-LicenseboxAccessLink $c}
   record {Add-LicenseboxUsage $c export $true .125;Add-LicenseboxUsage $c export $false .025;return $null}
  }
 } finally {Close-LicenseboxClient $c}
}
try {$value=Run-Adapter;@{ok=$true;value=$value}|ConvertTo-Json -Depth 50 -Compress}
catch {$e=$_.Exception;while($e.InnerException){$e=$e.InnerException};if($e -is [Licensebox.PowerShellNative.LicenseboxException]){@{ok=$false;error=$e.Code}|ConvertTo-Json -Compress}else{throw}}
