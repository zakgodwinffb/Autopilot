<#PSScriptInfo
.VERSION 1.1.1
.GUID 600c7e1b-44a5-4aaa-9644-b2763b9ccc5e
.AUTHOR AndrewTaylor
.DESCRIPTION Downloads and deploys troubleshooting tools to display in Autopilot ESP
.COMPANYNAME 
.COPYRIGHT GPL
.TAGS Intune Autopilot
.LICENSEURI https://github.com/andrew-s-taylor/public/blob/main/LICENSE
.PROJECTURI https://github.com/andrew-s-taylor/public
.ICONURI 
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS 
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>
<#
.SYNOPSIS
  Downloads and deploys troubleshooting tools to display in Autopilot ESP
.DESCRIPTION
Downloads and deploys troubleshooting tools to display in Autopilot ESP

.INPUTS
None required
.OUTPUTS
None required
.NOTES
  Version:        1.1.4
  Author:         Zak Godwin
  Creation Date:  03/08/2022
  Updated Date: 06/12/2023
  Updated Date: 03/07/2025
  Updated Date: 03/20/2025
  Purpose/Change: Initial script development
  Change: Added logic to stop running outside OOBE
  Change: Added command to auto-launch tools.  Thanks to Flo @ sunrise-it.fr
  Change: Fixed string output
  Change: Updated to use community script added AD Powershell module import
  Change: Updated download links to point to my repo and updated most variable names.

  Orig Author:    Andrew Taylor
  Twitter:        @AndrewTaylor_2
  WWW:            andrewstaylor.com
  
.EXAMPLE
N/A
#>


##Create a folder to store everything
$toolsPath = "$env:ProgramData\FFBTools"
If (Test-Path $toolsPath) {
  Write-Output "$toolsPath exists. Skipping."
}
Else {
  Write-Output "The folder '$toolsPath' doesn't exist. This folder will be used for storing logs created after the script runs. Creating now."
  Start-Sleep 1
  New-Item -Path "$toolsPath" -ItemType Directory
  Write-Output "The folder $toolsPath was successfully created."
}
##To install scripts
Set-ExecutionPolicy RemoteSigned -Force

##Set download locations
$serviceUiPath = "$toolsPath\serviceui.exe"
$cmtracePath = "$toolsPath\cmtrace.exe"
$scriptPath = "$toolsPath\tools.ps1"
$adModuleoutput = "$toolsPath\ActiveDirectory.zip"

##Force install NuGet (no popups)
install-packageprovider -Name NuGet -MinimumVersion 2.8.5.201 -Force

##Force install Autopilot Diagnostics (no popups)
Install-Script -Name Get-AutopilotDiagnosticsCommunity -Force


##Download ServiceUI
Invoke-WebRequest `
  -Uri "https://github.com/zakgodwinffb/Autopilot/raw/main/Troubleshooting/ServiceUI.exe" `
  -OutFile $serviceUiPath `
  -UseBasicParsing `
  -Headers @{"Cache-Control" = "no-cache" }

##Download CMTrace
Invoke-WebRequest `
  -Uri "https://github.com/zakgodwinffb/Autopilot/raw/main/Troubleshooting/CMTrace.exe" `
  -OutFile $cmtracePath `
  -UseBasicParsing `
  -Headers @{"Cache-Control" = "no-cache" }

##Download tools.ps1
Invoke-WebRequest `
  -Uri "https://github.com/zakgodwinffb/Autopilot/raw/main/Troubleshooting/tools.ps1" `
  -OutFile $scriptPath `
  -UseBasicParsing `
  -Headers @{"Cache-Control" = "no-cache" }

##Download ActiveDirectory.zip
Invoke-WebRequest `
  -Uri "https://github.com/zakgodwinffb/Autopilot/raw/main/Troubleshooting/ActiveDirectory.zip" `
  -OutFile $adModuleoutput `
  -UseBasicParsing `
  -Headers @{"Cache-Control" = "no-cache" }


# Prepare to import ActiveDirectory and GroupPolicy modules
if (-not (Test-Path -Path $adModuleoutput)) {
  Write-Error 'ActiveDirectory.zip file not found. Exiting.'
  Exit
}
else {
  Expand-Archive -Path $adModuleoutput -DestinationPath "$toolsPath\ActiveDirectory" -Force
}

# Import module DLL's into GAC and Powershell
if (-not (Test-Path -Path "$toolsPath\ActiveDirectory\GACs")) {
  Write-Error 'GAC DLLs not found. Exiting.'
  Exit
}
$GACFiles = Get-ChildItem -Path "$toolsPath\ActiveDirectory\GACs" -Recurse -Filter '*.dll'
foreach ($GAC in $GACFiles) {
  [System.Reflection.Assembly]::Load("System.EnterpriseServices, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a")            
  $publish = New-Object System.EnterpriseServices.Internal.Publish            
  $publish.GacInstall("$GAC.FullName")
    
  # Import the ActiveDirectory/GroupPolicy modules
  Import-Module $GAC.FullName -ErrorAction SilentlyContinue
}

##Create powershell script we are launching
$string = @"
# Send Shift+F10 key to open a command prompt
`$WscriptShell = New-Object -ComObject Wscript.Shell
`$WscriptShell.SendKeys("%({TAB})")
Start-Sleep 1
`$WscriptShell.SendKeys("+({F10})")
# Wait until cmd process is opened
Do {Start-Sleep 1} While (-not (Get-Process cmd -ErrorAction SilentlyContinue))
Start-Sleep 1
Get-Process cmd | Stop-Process -Force
Start-Process powershell.exe -ArgumentList '-nologo -noprofile -noexit -executionpolicy bypass -command $scriptPath ' -Wait
"@
$file2 = "$($toolsPath)\shiftf10.ps1"
$string | out-file $file2

##Check if we're during OOBE
$intunepath = "HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps"
$intunecomplete = @(Get-ChildItem $intunepath).count
if ($intunecomplete -lt 2) {

  ##Launch script with UI interaction
  Start-Process "$serviceUiPath" -ArgumentList ("-process:explorer.exe", 'c:\Windows\System32\WindowsPowershell\v1.0\powershell.exe -Executionpolicy bypass -file C:\ProgramData\FFBTools\shiftf10.ps1 -windowstyle Hidden')
  ##Add script here
}



