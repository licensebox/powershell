Set-StrictMode -Version Latest
if (-not ('Licensebox.PowerShellNative.Client' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot src/Native.cs) }
function New-LicenseboxClient {
 [CmdletBinding()]param([Parameter(Mandatory)][AllowEmptyString()][string]$Product,[Parameter(Mandatory)][System.Collections.IDictionary]$Keys,[string]$Version='',[string]$Server,[string]$Directory,[string]$CaBundle,[Func[double]]$Clock,[Func[string]]$MachineBinding,[Action[string,string]]$OnSignIn,[Func[bool]]$Cancelled)
 $trusted=[System.Collections.Generic.Dictionary[string,string]]::new();foreach($k in $Keys.Keys){$trusted.Add([string]$k,[string]$Keys[$k])}
 $cfg=[Licensebox.PowerShellNative.Config]::new($Product,$trusted);$cfg.Version=$Version
 if($PSBoundParameters.ContainsKey('Server')){$cfg.Server=$Server};if($PSBoundParameters.ContainsKey('Directory')){$cfg.Directory=$Directory};if($PSBoundParameters.ContainsKey('CaBundle')){$cfg.CaBundle=$CaBundle}
 $cfg.Clock=$Clock;$cfg.MachineBinding=$MachineBinding;$cfg.OnSignIn=$OnSignIn;$cfg.Cancelled=$Cancelled
 [Licensebox.PowerShellNative.Client]::new($cfg)
}
function Convert-LicenseboxValue {param([System.Text.Json.JsonElement]$Value);return ,(ConvertFrom-Json -AsHashtable -NoEnumerate -InputObject $Value.GetRawText())}
function Get-LicenseboxLease {param([Parameter(Mandatory)]$Client);Convert-LicenseboxValue $Client.Lease()}
function Invoke-LicenseboxHeartbeat {param([Parameter(Mandatory)]$Client,[Parameter(Mandatory)][AllowEmptyString()][string]$Module);Convert-LicenseboxValue $Client.Heartbeat($Module)}
function Assert-LicenseboxModule {param([Parameter(Mandatory)]$Client,[Parameter(Mandatory)][AllowEmptyString()][string]$Module);Convert-LicenseboxValue $Client.Require($Module)}
function Get-LicenseboxStatus {param([Parameter(Mandatory)]$Client);Convert-LicenseboxValue $Client.Status()}
function Connect-Licensebox {param([Parameter(Mandatory)]$Client,[double]$Timeout=0);Convert-LicenseboxValue $Client.SignIn($Timeout)}
function Disconnect-Licensebox {param([Parameter(Mandatory)]$Client);$Client.Logout()}
function Get-LicenseboxModule {param([Parameter(Mandatory)]$Client);Convert-LicenseboxValue $Client.Modules()}
function Get-LicenseboxRequest {param([Parameter(Mandatory)]$Client);Convert-LicenseboxValue $Client.Requests()}
function Request-LicenseboxAccess {param([Parameter(Mandatory)]$Client,[Parameter(Mandatory)][string[]]$Modules,[string]$Note='');Convert-LicenseboxValue $Client.RequestAccess($Modules,$Note)}
function Get-LicenseboxAccessLink {param([Parameter(Mandatory)]$Client);$Client.AccessLink()}
function Add-LicenseboxUsage {param([Parameter(Mandatory)]$Client,[Parameter(Mandatory)][AllowEmptyString()][string]$Command,[Parameter(Mandatory)][bool]$Success,[Parameter(Mandatory)][double]$Elapsed);$Client.Record($Command,$Success,$Elapsed)}
function Close-LicenseboxClient {param([Parameter(Mandatory)]$Client);$Client.Dispose()}
function Get-LicenseboxBinding {param([Parameter(Mandatory)][AllowEmptyString()][string]$Product);[Licensebox.PowerShellNative.Client]::NativeBinding($Product)}
function ConvertTo-LicenseboxBinding {param([Parameter(Mandatory)][AllowEmptyString()][string]$Product,[Parameter(Mandatory)][AllowEmptyString()][string]$Source,[Parameter(Mandatory)][AllowEmptyString()][string]$RawId);[Licensebox.PowerShellNative.Client]::DeriveBinding($Product,$Source,$RawId)}
function Test-LicenseboxLease {param([Parameter(Mandatory)][AllowEmptyString()][string]$Token,[Parameter(Mandatory)][AllowEmptyString()][string]$Product,[Parameter(Mandatory)][System.Collections.IDictionary]$Keys,[Parameter(Mandatory)][double]$Now)
 $trusted=[System.Collections.Generic.Dictionary[string,string]]::new();foreach($k in $Keys.Keys){$trusted.Add([string]$k,[string]$Keys[$k])};Convert-LicenseboxValue ([Licensebox.PowerShellNative.Client]::VerifyLease($Token,$Product,$trusted,$Now))
}
Export-ModuleMember -Function Invoke-LicenseboxHeartbeat,New-LicenseboxClient,Get-LicenseboxLease,Assert-LicenseboxModule,Get-LicenseboxStatus,Connect-Licensebox,Disconnect-Licensebox,Get-LicenseboxModule,Get-LicenseboxRequest,Request-LicenseboxAccess,Get-LicenseboxAccessLink,Add-LicenseboxUsage,Close-LicenseboxClient,Get-LicenseboxBinding,ConvertTo-LicenseboxBinding,Test-LicenseboxLease
