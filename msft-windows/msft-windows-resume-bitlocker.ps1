# Getting input from user if not running from RMM else set variables from RMM.

$ScriptLogName = "EnterLogNameHere.log"

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

# Function to resume BitLocker encryption on all volumes
function Resume-AllBitLocker {
    try {
        # Get all BitLocker volumes where BitLocker is suspended
        $suspendedBitLockerVolumes = Get-BitLockerVolume | Where-Object { $_.VolumeStatus -eq 'AutoUnlock' }

        if ($suspendedBitLockerVolumes.Count -gt 0) {
            foreach ($volume in $suspendedBitLockerVolumes) {
                # Resume BitLocker encryption
                Resume-BitLocker -MountPoint $volume.MountPoint -Verbose

                Write-Output "BitLocker encryption on volume $($volume.MountPoint) has been resumed."
            }
        } else {
            Write-Output "No BitLocker encrypted volumes with suspended encryption found."
        }
    }
    catch {
        Write-Error "An error occurred: $_"
        exit 2
    }
}

# Call the function to resume BitLocker on all volumes
Resume-AllBitLocker



Stop-Transcript
