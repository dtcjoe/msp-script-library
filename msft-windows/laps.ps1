# Getting input from user if not running from RMM else set variables from RMM.

$ScriptLogName = "laps.log"

if ($RMM -ne 1) {
    $ValidInput = 0
    # Checking for valid input.
    while ($ValidInput -ne 1) {
        # Ask for input here. This is the interactive area for getting variable information.
        # Remember to make ValidInput = 1 whenever correct input is given.
        $Description = Read-Host "Please enter the ticket # and, or your initials. Its used as the Description for the job"
        if ($Description) {
            $ValidInput = 1
        } else {
            Write-Host "Invalid input. Please try again."
        }
    }
    $LogPath = "$ENV:WINDIR\logs\$ScriptLogName"

} else { 
    # Store the logs in the RMMScriptPath
    if ($null -eq $RMMScriptPath) {
        $LogPath = "$RMMScriptPath\logs\$ScriptLogName"
        
    } else {
        $LogPath = "$ENV:WINDIR\logs\$ScriptLogName"
        
    }

    if ($null -eq $Description) {
        Write-Host "Description is null. This was most likely run automatically from the RMM and no information was passed."
        $Description = "No Description"
    }   


    
}

Start-Transcript -Path $LogPath

Write-Host "Description: $Description"
Write-Host "Log path: $LogPath"
Write-Host "RMM: $RMM"

# Check if the computer is a domain controller or Azure AD joined
# PowerShell Script to Check if the Server is a Domain Controller
$serverRole = Get-WmiObject -Class Win32_ComputerSystem

if ($serverRole.DomainRole -eq 4 -or $serverRole.DomainRole -eq 5) {
    Write-Host "This server IS a Domain Controller. Exiting"
    Exit 0
} else {
    Write-Host "This server is NOT a Domain Controller."
    Write-Host "Continuing to run LAPS."
}

# Function to check if azure ad joined
function Test-AzureAdJoined {
        $AzureADKey = Test-Path "HKLM:/SYSTEM/CurrentControlSet/Control/CloudDomainJoin/JoinInfo"
        if ($AzureADKey) {
            $subKey = Get-Item "HKLM:/SYSTEM/CurrentControlSet/Control/CloudDomainJoin/JoinInfo/*"
    
            try {
                foreach($key in $subKey) {
                    $tenantId = $key.GetValue("TenantId");
                    $userEmail = $key.GetValue("UserEmail");
                }

                Write-Host "Tenant ID: $($tenantId)" 
                Write-Host "User Email: $($userEmail)"
                if ($tenantId) { 
                    return $True
                } else {
                    return $False
                }
            } catch {
                return $False
            }
        } else {
                return $False
        }
}

# Function to generate a random password
function Generate-RandomPassword {
    $symbols = '!@#$%^&*()_+-=[]{}|;:,.<>?'
    $characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789' + $symbols
    $password = ""
    for ($i = 0; $i -lt 32; $i++) {
        $password += $characters[(Get-Random -Minimum 0 -Maximum $characters.Length)]
    }
    return $Password
}

# Function to check if a user exists
function User-Exists {
    param(
        [string]$username
    )
    $user = Get-LocalUser -Name $username
    return [bool]($user -ne $null)
}

# Function to add a user to the local Administrators group
function Add-UserToLocalAdministrators {
    param(
        [string]$username
    )
    $group = [ADSI]"WinNT://./Administrators,group"
    $group.Add("WinNT://$env:COMPUTERNAME/$username")
}

# Generate a random password
$password = Generate-RandomPassword

# Specify the local user
# $localUser = "username"  # Replace "username" with the desired local user

# Check if the user exists
if (!(User-Exists -username $localUser)) {
    # Create the local user if it doesn't exist
    Write-Host "Creating new local user $localuser."
    $SecurePassword = ConvertTo-SecureString -String "$password" -AsPlainText -Force
    $newUser = New-LocalUser -Name $localUser -Password $SecurePassword -PasswordNeverExpires:$True -UserMayNotChangePassword:$True -AccountNeverExpires:$True
    if ($null -eq $newUser) {
        Write-Host "Failed to create user $localUser."
        Exit 1
    }
    Write-Host "Local user $localuser created."
    Write-Host "Adding user to local Administrators group."
    # Add the user to the local Administrators group
    Add-UserToLocalAdministrators -username $localUser
} else {
    # Add the existing user to the local Administrators group
    Add-UserToLocalAdministrators -username $localUser
}

# Set password for specified local user
net user $localUser $password > $null  # Redirect output to suppress password display
# Display a message about password setting completion
Write-Host "Password set for user $localUser."
# Check if the computer is domain-joined

# Testing if endpoint is joined to a legacy Windows Active Directory domain.
if (Test-ComputerSecureChannel) {
    # Set password for built-in administrator
    Write-Host "Endpoint joined to domain. Setting password for Built-in Administrator and disabling."
    $adminUsername = "Administrator"
    net user $adminUsername $password > $null  # Redirect output to suppress password display
    Write-Host "Password set for built-in administrator."
    net user administrator /active:no > $null
    Write-Host "Built-in Administrator disabled."
    Exit 0

} else {
    Write-Host "Endpoint is not domain joined. Not diabling or resetting Built-in Administrator."
}

# Testing if endpoint is Azure AD joined.
if (Test-AzureADJoined) { 
        # Set password for built-in administrator
        Write-Host "Endpoint joined to Microsoft Entra ID. Setting password for Built-in Administrator and disabling."
        $adminUsername = "Administrator"
        net user $adminUsername $password > $null  # Redirect output to suppress password display
        Write-Host "Password set for built-in administrator."
        net user administrator /active:no > $null
        Write-Host "Built-in Administrator disabled."
        Exit 0

} else {
    Write-Host "Endpoint is not Azure AD Joined. Not disabling or resetting Built-in Administrator"
}


# You can uncomment the next line if you want to log the generated password for your reference
# Write-Host "Generated Password: $password"


Stop-Transcript
