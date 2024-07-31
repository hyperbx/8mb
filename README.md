# 8mb
8MB video compression PowerShell script for ffmpeg.

# Prerequisites
- Windows PowerShell
- [ffmpeg](https://ffbinaries.com/downloads)
- [ffprobe](https://ffbinaries.com/downloads)

# Usage
## Shell Extension
Run `Register.bat` from the permanent location of `8mb.ps1` to extend the context menu of `*.mp4` files with the script.

<p align="center">
    <img src="https://github.com/user-attachments/assets/b7239e80-2ecf-4d5c-a3f0-11ceadc4c716"/>
</p>

Right-clicking any `*.mp4` file will have a new sub-menu with different size presets.

If the location of `8mb.ps1` changes, running `Register.bat` again will update the location in the registry accordingly.

## Command Line
```ps
PS > .\8mb.ps1 -Source [Path]
               -Size [UInt32]
               -SizeUnits (optional) [KB|MB (default)]
               -FPS (optional) [UInt32]
               -Destination (optional) [Path]
```

# Example
```ps
PS > .\8mb.ps1 a.mp4 8 MB
8mb PowerShell

Source Path ------ : a.mp4
Destination Path - : a.8mb.mp4
Source Size ------ : 205,834 KB (210,774,113 bytes)
Destination Size - : 8,192 KB (8,388,608 bytes)

Starting transcode at 07/31/2024 21:04:37. Enter CTRL+C to cancel.

Attempt 1: Transcoding at 899 Kbps using 12 CPU cores...
           Compressed to 8,083 KB.

Finished at 07/31/2024 21:05:15 in 37.909302 seconds after 1 attempt.
```
