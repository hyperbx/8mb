# 8mb
8MB video compression PowerShell script for ffmpeg.

# Prerequisites
- Windows PowerShell
- [ffmpeg](https://ffbinaries.com/downloads)
- [ffprobe](https://ffbinaries.com/downloads)

# Usage
Download the Windows binaries for both ffmpeg and ffprobe from the [Prerequisites](#prerequisites) section and extract them into the script directory.

## Shell Extension
Run `Register.bat` to extend the context menu of `*.mp4` files with the script.

<p align="center">
    <img src="https://github.com/user-attachments/assets/b7239e80-2ecf-4d5c-a3f0-11ceadc4c716"/>
</p>

Right-clicking any `*.mp4` file will have a new sub-menu with different size presets.

If the location of `8mb.ps1` changes, running `Register.bat` again will update the location in the registry accordingly.

## Command Line
```ps
PS > .\8mb.ps1 -Source [Path]
               -Size [UInt32]
               -SizeUnits [KB|MB (default)] (optional)
               -Scale [Single] (optional)
               -FPS [UInt32] (optional)
               -Destination [Path] (optional)
```

# Example
```ps
PS > .\8mb.ps1 a.mp4 8 MB
8mb PowerShell

Source ===================================

Path -- : D:\Source\Forks\hyperbx\8mb\a.mp4
Size -- : 210,774 KB (210,774,113 bytes)
Scale - : 1 (2560x1072)
FPS --- : 60 FPS

Destination ==============================

Path -- : D:\Source\Forks\hyperbx\8mb\a.8mb.mp4
Size -- : 8,000 KB (8,000,000 bytes)
Scale - : 0.5 (1280x536)
FPS --- : 30 FPS

Starting transcode at 08/01/2024 02:13:36. Enter CTRL+C to cancel.

Attempt 1: Transcoding at 870 Kbps using 12 CPU cores...
           Compressed to 7,881 KB.

Finished at 08/01/2024 02:13:48 in 11.4919225 seconds after 1 attempt.
```
