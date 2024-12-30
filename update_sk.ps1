# Function to determine version of a DLL
function Get-DLLVersion {
    param ([string]$FilePath)

    try {
        $FileVersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath)
        return $FileVersionInfo.FileVersion
    } catch {
        Write-Warning "Failed to get version info for ${FilePath}: $($_.Exception.Message)"
        return $null
    }
}


# Function to determine the bitness of a DLL
function Get-DLLBitness {
    param ([string]$FilePath)

    try {
        $Bytes = [System.IO.File]::ReadAllBytes($FilePath)

        # Check for the PE signature (offset 0x3C gives the location of the PE header)
        $PESignatureOffset = [BitConverter]::ToInt32($Bytes, 0x3C)
        $PESignature = [System.Text.Encoding]::ASCII.GetString($Bytes, $PESignatureOffset, 4)

        if ($PESignature -ne "PE`0`0") {
            throw "Invalid PE signature"
        }

        # Check the Machine field in the COFF header
        $Machine = [BitConverter]::ToUInt16($Bytes, $PESignatureOffset + 4)
        switch ($Machine) {
            0x8664 { return "64-bit" }
            0x014C { return "32-bit" }
            default { return "Unknown architecture" }
        }
    } catch {
        Write-Warning "Failed to determine bitness for ${FilePath}: $($_.Exception.Message)"
        return "Unknown"
    }
}

# Function to set colored output
function Write-ColoredLog {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Check if a directory was dragged onto the script
if ($args.Count -eq 1 -and (Test-Path $args[0])) {
    $SearchRoots = @($args[0])
} else {
    # If no directory is provided, read directories from game_paths.txt
    $ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    $GamePathsFile = Join-Path -Path $ScriptDirectory -ChildPath "game_paths.txt"

    if (!(Test-Path $GamePathsFile)) {
        Write-ColoredLog "No directory provided and game_paths.txt not found in script directory." -Color "Red"
        exit 1
    }

    $SearchRoots = Get-Content -Path $GamePathsFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not ($_ -match '^;') -and (Test-Path $_) }

    if ($SearchRoots.Count -eq 0) {
        Write-ColoredLog "No valid directories found in game_paths.txt." -Color "Red"
        exit 1
    }
}

# Load blacklist.txt
$BlacklistFile = Join-Path -Path $ScriptDirectory -ChildPath "blacklist.txt"
$Blacklist = @()
if (Test-Path $BlacklistFile) {
    $Blacklist = Get-Content -Path $BlacklistFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" -and -not ($_ -match '^;') }
}

# Path to the replacement DLL files (located alongside the script)
$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$ReplacementDLL32 = Join-Path -Path $ScriptDirectory -ChildPath "SpecialK32.dll"
$ReplacementDLL64 = Join-Path -Path $ScriptDirectory -ChildPath "SpecialK64.dll"

# Backup path for replacement DLLs
$BackupDLLPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Programs\Special K"
$BackupDLL32 = Join-Path -Path $BackupDLLPath -ChildPath "SpecialK32.dll"
$BackupDLL64 = Join-Path -Path $BackupDLLPath -ChildPath "SpecialK64.dll"

# Ensure both replacement DLLs exist, fallback to backup location if not
if (!(Test-Path $ReplacementDLL32)) {
    if (Test-Path $BackupDLL32) {
        Write-ColoredLog "Primary 32-bit replacement DLL not found, using backup: $BackupDLL32" -Color "Yellow"
        $ReplacementDLL32 = $BackupDLL32
    } else {
        Write-ColoredLog "Replacement DLL not found: $ReplacementDLL32 or backup: $BackupDLL32" -Color "Red"
        exit 1
    }
}
if (!(Test-Path $ReplacementDLL64)) {
    if (Test-Path $BackupDLL64) {
        Write-ColoredLog "Primary 64-bit replacement DLL not found, using backup: $BackupDLL64" -Color "Yellow"
        $ReplacementDLL64 = $BackupDLL64
    } else {
        Write-ColoredLog "Replacement DLL not found: $ReplacementDLL64 or backup: $BackupDLL64" -Color "Red"
        exit 1
    }
}

$MatchingFiles = @()
$GamesSearched = 0
$GamesUpdated = 0
$GamesSkipped = 0

# Process each search root
foreach ($SearchRoot in $SearchRoots) {
    Write-ColoredLog "Searching root directory: $SearchRoot..." -Color "Cyan"

    # Get first-level subdirectories
    $SubDirectories = Get-ChildItem -Path $SearchRoot -Directory

    foreach ($SubDirectory in $SubDirectories) {
        # Skip blacklisted folders
        if ($Blacklist -contains $SubDirectory.Name) {
            Write-ColoredLog "Skipping blacklisted folder: $($SubDirectory.Name)" -Color "Magenta"
            $GamesSkipped++
            continue
        }

        Write-ColoredLog "Checking $($SubDirectory.Name)..." -Color "Cyan"
        $GamesSearched++  # Increment for each first-level subdirectory

        # Process DLL files within this subdirectory (existing logic)
        Get-ChildItem -Path $SubDirectory.FullName -Recurse -Filter "*.dll" | ForEach-Object {
            $File = $_
            try {
                # Get the file version info
                $FileVersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($File.FullName)

                # Check if the file description contains "Special K"
                if ($FileVersionInfo.FileDescription -like "*Special K*") {
                    $MatchingFiles += $File.FullName
                    $Bitness = Get-DLLBitness -FilePath $File.FullName
                    $Version = Get-DLLVersion -FilePath $File.FullName
                    Write-ColoredLog "Found $($File.Name) ($Version $Bitness)" -Color "Green"

                    # Select the appropriate replacement DLL
                    $ReplacementDLL = if ($Bitness -eq "64-bit") { $ReplacementDLL64 } elseif ($Bitness -eq "32-bit") { $ReplacementDLL32 } else { $null }

                    $ReplacementVersion = Get-DLLVersion -FilePath $ReplacementDLL
                    $NewerVersion = [version]$ReplacementVersion -gt [version]$Version

                    iF (-not $NewerVersion) {
                        Write-ColoredLog "No update required..." -Color "Green"
                        return
                    }

                    if ($ReplacementDLL) {
                        # Replace the file with the same name
                        try {
                            Copy-Item -Path $ReplacementDLL -Destination $File.FullName -Force
                            Write-ColoredLog "Updating $($File.Name) to $ReplacementVersion" -Color "Green"
                            $GamesUpdated++
                        } catch {
                            Write-ColoredLog "Failed to replace $($File.FullName): $_" -Color "Red"
                        }
                    } else {
                        Write-ColoredLog "Unknown bitness for $($File.FullName), skipping replacement." -Color "Yellow"
                    }
                }
            } catch {
                Write-ColoredLog "Failed to get version info for $($File.FullName): $($_.Exception.Message)" -Color "Yellow"
            }
        }
    }
}

if ($MatchingFiles.Count -eq 0) {
    Write-ColoredLog "No matching DLLs found to update." -Color "Yellow"
}

Write-ColoredLog "Total games searched: $GamesSearched" -Color "White"
Write-ColoredLog "Total games updated: $GamesUpdated" -Color "Green"
Write-ColoredLog "Total games skipped (blacklisted): $GamesSkipped" -Color "Magenta"

Write-ColoredLog "Script execution completed. Press any key to exit..." -Color "Cyan"
[System.Console]::ReadKey()
