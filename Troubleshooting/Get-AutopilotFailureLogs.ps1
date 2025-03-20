# Define the remote computer name
$remoteComputer = "$($env:ComputerName)"

# Function to get Intune logs
function Get-IntuneLogs {
    param (
        [string]$computerName
    )
    Invoke-Command -ComputerName $computerName -ScriptBlock {
        Get-ChildItem -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs" -Filter "*.log" | Select-Object FullName, LastWriteTime
    }
}

# Function to check application installation status
function Get-AppInstallationStatus {
    param (
        [string]$computerName,
        [string]$appName
    )
    Invoke-Command -ComputerName $computerName -ScriptBlock {
        Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name = '$appName'" | Select-Object Name, Version, InstallDate
    }
}

# Function to get relevant event logs
function Get-EventLogs {
    param (
        [string]$computerName
    )
    Invoke-Command -ComputerName $computerName -ScriptBlock {
        Get-EventLog -LogName Application -EntryType Error, Warning -Source "IntuneManagementExtension" | Select-Object TimeGenerated, EntryType, Source, Message
    }
}

# Get Intune logs
Write-Host "Fetching Intune logs from $remoteComputer..."
Get-IntuneLogs -computerName $remoteComputer

# Check application installation status
$appName = "Cisco Secure Client - AnyConnect VPN"
Write-Host "Checking installation status of $appName on $remoteComputer..."
Get-AppInstallationStatus -computerName $remoteComputer -appName $appName

# Get relevant event logs
Write-Host "Fetching relevant event logs from $remoteComputer..."
Get-EventLogs -computerName $remoteComputer