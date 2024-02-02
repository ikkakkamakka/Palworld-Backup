#While Palworld Server runs, this will locate and backup save data.
function Find-PalworldProcessDirectory {
    try {
        $process = Get-Process PalServer -ErrorAction Stop
        $exePath = $process.MainModule.FileName
        Write-Host "PalServer process found: $exePath"
        return Split-Path $exePath
    } catch {
        Write-Error "PalServer process not found."
        return $null
    }
}

function Get-DedicatedServerId {
    param ([string]$palServerPath)
    
    $configFilePath = Join-Path -Path $palServerPath -ChildPath "Pal\Saved\Config\WindowsServer\GameUserSettings.ini"
    
    if (Test-Path $configFilePath) {
        $content = Get-Content $configFilePath -ErrorAction Stop
        foreach ($line in $content) {
            if ($line -match "DedicatedServerName=(.+)") {
                $serverId = $matches[1].Trim()
                Write-Host "Found server ID: '$serverId'"
                return $serverId
            }
        }
        Write-Error "DedicatedServerName entry not found in GameUserSettings.ini."
    } else {
        Write-Error "Configuration file not found: $configFilePath"
    }
    return $null
}

function Create-Backup {
    param (
        [string]$sourcePath,
        [string]$backupRootDir,
        [string]$serverId
    )
    
    $date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    # Adjust the destination path to include the server ID first, then the timestamp
    $dest = Join-Path -Path $backupRootDir -ChildPath $serverId
    $dest = Join-Path -Path $dest -ChildPath $date
    
    Write-Host "Creating backup folder: $dest"
    # Check if the server ID directory exists, if not, create it
    if (-not (Test-Path $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }
    
    Copy-Item -Path $sourcePath -Destination $dest -Recurse -Force
    Write-Host "Backup of $sourcePath completed."
}


# This function encapsulates the backup logic and repeats it every 10 minutes.
function Perform-RepeatedBackups {
    try {
        $palworldRootDir = Find-PalworldProcessDirectory
        if ($null -eq $palworldRootDir) { throw "Unable to locate Palworld process directory." }

        $serverId = Get-DedicatedServerId -palServerPath $palworldRootDir
        if ($null -eq $serverId) { throw "Unable to retrieve Dedicated Server ID from configuration." }

        $saveGamesDir = Join-Path -Path $palworldRootDir -ChildPath "Pal\Saved\SaveGames\0\$serverId"
        if (-not (Test-Path $saveGamesDir)) { throw "SaveGames directory for server ID '$serverId' not found." }

        $backupRootDir = Join-Path -Path $palworldRootDir -ChildPath "Pal\Saved\SaveGames\Backups"
        if (-not (Test-Path $backupRootDir)) { New-Item -ItemType Directory -Path $backupRootDir | Out-Null }

        while ($true) {
            Create-Backup -sourcePath $saveGamesDir -backupRootDir $backupRootDir -serverId $serverId
            Start-Sleep -Seconds 600 # Sleep for 10 minutes
        }
    } catch {
        Write-Error $_
    }
}

# Start the backup process.
Perform-RepeatedBackups