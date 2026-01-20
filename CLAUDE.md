# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SpecialKLocalUpdater is a PowerShell-based utility for bulk-updating Special K DLL files across multiple game directories. Special K is a game modding framework that injects via DLL.

## Running the Script

```batch
# Via batch wrapper (recommended)
update_sk.bat

# With specific directory (drag-and-drop supported on .bat file)
update_sk.bat "C:\Games\SomeGame"

# Direct PowerShell execution
powershell -NoProfile -ExecutionPolicy Bypass -File update_sk.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File update_sk.ps1 "C:\Games\SomeGame"
```

## Architecture

**Entry Point:** `update_sk.bat` - Batch wrapper that handles argument passing and ExecutionPolicy bypass for the PowerShell script.

**Core Script:** `update_sk.ps1` - Main logic:
1. Determines search roots from either command-line argument or `game_paths.txt`
2. Loads blacklist from `blacklist.txt`
3. Locates replacement DLLs (script directory first, then `%LocalAppData%\Programs\Special K` fallback)
4. Iterates first-level subdirectories of each search root
5. Recursively scans for DLLs with "Special K" in FileDescription
6. Compares versions and replaces outdated DLLs with architecture-matched replacements

**Key Functions:**
- `Get-DLLVersion` - Extracts FileVersion from DLL metadata
- `Get-DLLBitness` - Reads PE header to determine 32-bit vs 64-bit architecture
- `Write-ColoredLog` - Console output with color coding

## Configuration Files

Both files use `;` prefix for comments:
- `game_paths.txt` - Root directories to scan (one per line)
- `blacklist.txt` - Game folder names to skip (matches first-level subdirectory names only)

## DLL Detection Logic

The script identifies Special K DLLs by checking `FileVersionInfo.FileDescription` for "Special K" substring, not by filename. This allows detection regardless of what the DLL was renamed to (common names: dxgi.dll, d3d11.dll, dinput8.dll, etc.).
