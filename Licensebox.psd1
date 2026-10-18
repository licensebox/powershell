@{
 RootModule='Licensebox.psm1';ModuleVersion='0.1.0';GUID='13422023-721e-4b68-96fb-c7b186198a7a'
 Author='Vijai Kumar';Copyright='2026 Vijai Kumar';Description='Native Licensebox application licensing SDK'
 PowerShellVersion='7.4';CompatiblePSEditions=@('Core')
 FunctionsToExport=@('Invoke-LicenseboxHeartbeat','New-LicenseboxClient','Get-LicenseboxLease','Assert-LicenseboxModule','Get-LicenseboxStatus','Connect-Licensebox','Disconnect-Licensebox','Get-LicenseboxModule','Get-LicenseboxRequest','Request-LicenseboxAccess','Get-LicenseboxAccessLink','Add-LicenseboxUsage','Close-LicenseboxClient','Get-LicenseboxBinding','ConvertTo-LicenseboxBinding','Test-LicenseboxLease')
 CmdletsToExport=@();VariablesToExport=@();AliasesToExport=@()
 PrivateData=@{PSData=@{LicenseUri='https://opensource.org/license/mit';ProjectUri='https://meshing.engineer';Tags=@('Licensebox','Licensing','Native')}}
}
