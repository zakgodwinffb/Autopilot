# Prompt for domain controller IP address
$domainController = Read-Host -Prompt "Enter the domain controller IP address"

# Validate IP address format
if (-not ([System.Net.IPAddress]::TryParse($domainController, [ref]$null))) {
    Write-Error "Invalid IP address format. Please enter a valid IP address."
    exit
}

# Define the ports required for Active Directory domain join
$ports = @(53, 88, 135, 389, 445, 636, 3268, 3269)


# Define the ports required for Microsoft servers
$microsoftPorts = @(80, 443)


# Define the Microsoft servers for Autopilot hybrid join
$microsoftServers = @("enterpriseregistration.windows.net", "login.microsoftonline.com")


# Prompt for credentials
$credential = Get-Credential -Message "Enter credentials (leave blank to use current user)" -UserName "hq\zgodwin"


# Function to test port connectivity
function Test-Port {
    param (
        [string]$server,
        [int]$port
    )
    try {
        $tcpConnection = Test-NetConnection -ComputerName $server -Port $port
        if ($tcpConnection.TcpTestSucceeded) {
            return "Open"
        }
        else {
            return "Closed"
        }
    }
    catch {
        return "Error"
    }
}


# Retrieve all domain controllers from the specified server
if ($credential -and $credential.UserName -ne "") {
    $domainControllers = Get-ADDomainController -Filter * -Server $domainController -Credential $credential
}
else {
    $domainControllers = Get-ADDomainController -Filter * -Server $domainController
}


# Outout list of Domain controllers
Write-Output "Domain Controllers:`n $domainControllers"


# Initialize results array
$results = @()


# Test ports for each domain controller
foreach ($dc in $domainControllers) {
    Write-Output "Testing ports for domain controller: $($dc.Name)"
    foreach ($port in $ports) {
        $result = Test-Port -server $dc.IPv4Address -port $port
        $results += [PSCustomObject]@{
            Server = $dc.Name
            Port   = $port
            Status = $result
        }
    }
}


# Test connection to Microsoft servers
foreach ($server in $microsoftServers) {
    Write-Output "Testing connection to Microsoft server: $server"
    foreach ($port in $microsoftPorts) {
        $result = Test-Port -server $server -port $port
        $results += [PSCustomObject]@{
            Server = $server
            Port   = $port
            Status = $result
        }
    }
}


# Generate a timestamp suffix
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"


# Define the CSV file path with timestamp suffix
$scriptRoot = $PSScriptRoot
$csvFilePath = "$scriptRoot\port_test_results_$timestamp.csv"


# Export results to CSV
$results | Export-Csv -Path $csvFilePath -NoTypeInformation


Write-Output "The results have been exported to $csvFilePath"