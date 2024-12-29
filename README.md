# Special K Replacement Script

This PowerShell script automates the process of updating DLL files for games, particularly for the "Special K" framework. It supports bulk operations, handling multiple game directories, and ensures no unintentional updates through a configurable blacklist.

## Features

- **DLL Replacement:** Automatically replaces existing Special K DLLs with updated versions for both 32-bit and 64-bit architectures.
- **Multi-Directory Support:** Process multiple game directories at once by specifying them in a `game_paths.txt` file or dragging a directory onto the script.
- **Blacklist Management:** Skip specific game folders by adding their names to a `blacklist.txt` file.
- **Comments in Configuration Files:** Lines starting with `;` in `game_paths.txt` or `blacklist.txt` are treated as comments and ignored.
- **Dynamic Backup Support:** If replacement DLLs are not found locally, the script looks for backups in `%LocalAppData%\Programs\Special K` (default install location for Special K).
- **Colored Output:** Provides clear and color-coded log messages for better readability.

## Requirements

- Windows OS
- PowerShell
- The updated DLLs (`SpecialK32.dll` and `SpecialK64.dll`) located alongside the script or in the backup path.

## Installation

1. Clone this repository or download the script.
2. Ensure you have the updated `SpecialK32.dll` and `SpecialK64.dll` files either:
   - In the same folder as the script.
   - In the backup folder: `%LocalAppData%\Programs\Special K` (default install location for Special K).

## Usage

### 1. Drag and Drop

Drag and drop a game directory onto the script (`update_sk.ps1`) to process only that directory.

### 2. Use `game_paths.txt`

- Create a `game_paths.txt` file in the script directory.
- Add paths to the game directories you want to process, one per line.
- Add comments using lines starting with `;`.

Example:

```
; Path to my Steam games
C:\Games\Steam

; Another path
D:\Games\Other
```

### 3. Blacklist Specific Games

- Create a `blacklist.txt` file in the script directory.
- Add game folder names to exclude from processing, one per line.
- Add comments using lines starting with `;`.

Example:

```
; Skip CoreKeeper
CoreKeeper

; Skip DarkAndDarker
DarkAndDarker
```

### 4. Run the Script

- Open a PowerShell terminal.
- Run the script directly:
  ```
  .\update_sk.ps1
  ```

### Output

The script provides color-coded output:

- **Cyan:** General progress (e.g., searching directories).
- **Green:** Successful replacements and matches.
- **Yellow:** Warnings or fallback paths used.
- **Magenta:** Skipped folders (blacklisted).
- **Red:** Errors or critical issues.

At the end of execution, the script displays a summary:

- Total games searched.
- Total games updated.
- Total games skipped (blacklisted).

### Pause on Completion

The script waits for a keypress before closing, so you can review the log output.

## License

This script is provided "as is" without warranty of any kind. Use it at your own risk.

---

For questions or support, feel free to create an issue in this repository.
