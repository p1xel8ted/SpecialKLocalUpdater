param (
    [switch]$Verbose,
    [string]$Path
)

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
        # Read only the first 1KB instead of entire file
        $Stream = [System.IO.File]::OpenRead($FilePath)
        $Bytes = New-Object byte[] 1024
        $null = $Stream.Read($Bytes, 0, 1024)
        $Stream.Close()

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

# Function for verbose logging
function Write-VerboseLog {
    param ([string]$Message)
    if ($Verbose) {
        Write-Host "  [VERBOSE] $Message" -ForegroundColor DarkGray
    }
}

# Check if a directory was provided via parameter
if ($Path -and (Test-Path $Path)) {
    $SearchRoots = @($Path)
    Write-VerboseLog "Using provided path: $Path"
} else {
    # If no directory is provided, read directories from game_paths.txt
    $ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    $GamePathsFile = Join-Path -Path $ScriptDirectory -ChildPath "game_paths.txt"

    if (!(Test-Path $GamePathsFile)) {
        Write-ColoredLog "No directory provided and game_paths.txt not found in script directory." -Color "Red"
        exit 1
    }

    $SearchRoots = Get-Content -LiteralPath $GamePathsFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -and -not ($_ -match '^;') -and (Test-Path $_) }
    Write-VerboseLog "Loaded $($SearchRoots.Count) search roots from game_paths.txt"

    if ($SearchRoots.Count -eq 0) {
        Write-ColoredLog "No valid directories found in game_paths.txt." -Color "Red"
        exit 1
    }
}

# Load blacklist.txt
$BlacklistFile = Join-Path -Path $ScriptDirectory -ChildPath "blacklist.txt"
$Blacklist = @()
if (Test-Path $BlacklistFile) {
    $Blacklist = Get-Content -LiteralPath $BlacklistFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" -and -not ($_ -match '^;') }
    Write-VerboseLog "Loaded $($Blacklist.Count) blacklisted folders"
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

# Cache replacement DLL versions upfront
$ReplacementVersion32 = Get-DLLVersion -FilePath $ReplacementDLL32
$ReplacementVersion64 = Get-DLLVersion -FilePath $ReplacementDLL64
Write-VerboseLog "Replacement DLL versions: 32-bit=$ReplacementVersion32, 64-bit=$ReplacementVersion64"

# Directories to skip (mod loaders, etc.)
$SkipDirectories = @(
    "MelonLoader",
    "BepInEx",
    "doorstop_libs"
)

# DLL names that Special K can inject as (whitelist)
$SpecialKTargets = @(
    "bink2w32.dll",
    "bink2w64.dll",
    "binkw32.dll",
    "binkw64.dll",
    "d3d8.dll",
    "d3d9.dll",
    "d3d10.dll",
    "d3d11.dll",
    "d3d12.dll",
    "ddraw.dll",
    "dinput.dll",
    "dinput8.dll",
    "dsound.dll",
    "dxgi.dll",
    "msacm32.dll",
    "msvfw32.dll",
    "opengl32.dll",
    "version.dll",
    "vorbisFile.dll",
    "winhttp.dll",
    "wininet.dll",
    "winmm.dll",
    "xinput1_1.dll",
    "xinput1_2.dll",
    "xinput1_3.dll",
    "xinput1_4.dll",
    "xinput9_1_0.dll",
    "xinputuap.dll",
    "xlive.dll"
)

$MatchingFiles = @()
$GamesSearched = 0
$GamesUpdated = 0
$GamesSkipped = 0

# Process each search root
foreach ($SearchRoot in $SearchRoots) {
    Write-ColoredLog "Searching root directory: $SearchRoot..." -Color "Cyan"

    # Get first-level subdirectories
    $SubDirectories = Get-ChildItem -LiteralPath $SearchRoot -Directory

    foreach ($SubDirectory in $SubDirectories) {
        # Skip blacklisted folders
        if ($Blacklist -contains $SubDirectory.Name) {
            Write-ColoredLog "Skipping blacklisted folder: $($SubDirectory.Name)" -Color "Magenta"
            $GamesSkipped++
            continue
        }

        Write-ColoredLog "Checking $($SubDirectory.Name)..." -Color "Cyan"
        $GamesSearched++  # Increment for each first-level subdirectory

        # Find exe directories, then only check DLLs in those directories
        $ExeDirectories = Get-ChildItem -LiteralPath $SubDirectory.FullName -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty DirectoryName -Unique

        Write-VerboseLog "Found $(@($ExeDirectories).Count) exe directories in $($SubDirectory.Name)"

        foreach ($ExeDir in $ExeDirectories) {
            # Skip mod loader directories
            $ShouldSkip = $false
            foreach ($SkipDir in $SkipDirectories) {
                if ($ExeDir -like "*\$SkipDir\*" -or $ExeDir -like "*\$SkipDir") {
                    Write-VerboseLog "Skipping mod loader directory: $ExeDir"
                    $ShouldSkip = $true
                    break
                }
            }
            if ($ShouldSkip) { continue }

            Write-VerboseLog "Scanning: $ExeDir"
            Get-ChildItem -LiteralPath $ExeDir -Filter "*.dll" -ErrorAction SilentlyContinue | ForEach-Object {
                $File = $_

                # Only check DLLs that match known Special K target names
                if ($SpecialKTargets -notcontains $File.Name) { return }

                try {
                    Write-VerboseLog "Checking: $($File.Name)"
                    # Get the file version info
                    $FileVersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($File.FullName)

                    # Check if the file description contains "Special K"
                    if ($FileVersionInfo.FileDescription -like "*Special K*") {
                        $MatchingFiles += $File.FullName
                        $Bitness = Get-DLLBitness -FilePath $File.FullName
                        $Version = $FileVersionInfo.FileVersion
                        Write-ColoredLog "Found $($File.Name) ($Version $Bitness)" -Color "Green"

                        # Select the appropriate replacement DLL and cached version
                        $ReplacementDLL = if ($Bitness -eq "64-bit") { $ReplacementDLL64 } elseif ($Bitness -eq "32-bit") { $ReplacementDLL32 } else { $null }
                        $ReplacementVersion = if ($Bitness -eq "64-bit") { $ReplacementVersion64 } elseif ($Bitness -eq "32-bit") { $ReplacementVersion32 } else { $null }
                        $NewerVersion = [version]$ReplacementVersion -gt [version]$Version

                        if (-not $NewerVersion) {
                            Write-ColoredLog "No update required..." -Color "Green"
                            return
                        }

                        if ($ReplacementDLL) {
                            # Replace the file with the same name
                            try {
                                Copy-Item -LiteralPath $ReplacementDLL -Destination $File.FullName -Force
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
}

if ($MatchingFiles.Count -eq 0) {
    Write-ColoredLog "No matching DLLs found to update." -Color "Yellow"
}

Write-ColoredLog "Total games searched: $GamesSearched" -Color "White"
Write-ColoredLog "Total games updated: $GamesUpdated" -Color "Green"
Write-ColoredLog "Total games skipped (blacklisted): $GamesSkipped" -Color "Magenta"

Write-ColoredLog "Script execution completed. Press any key to exit..." -Color "Cyan"
[System.Console]::ReadKey()
