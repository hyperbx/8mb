# 8mb
8MB video compression PowerShell script for ffmpeg.

# Prerequisites
- Windows PowerShell
- [ffmpeg](https://ffbinaries.com/downloads)
- [ffprobe](https://ffbinaries.com/downloads)

# Usage
Download the Windows binaries for both ffmpeg and ffprobe from the [Prerequisites](#prerequisites) section and extract them into the script directory.

If either binaries are in PATH, they will be searched for there first.

## Shell Extension
Run `Register.bat` to extend the context menu of `*.mp4` files with the script.

<p align="center">
    <img src="https://github.com/user-attachments/assets/b7239e80-2ecf-4d5c-a3f0-11ceadc4c716"/>
</p>

Right-clicking any `*.mp4` file will have a new sub-menu with different size presets.

If the location of `8mb.ps1` changes, running `Register.bat` again will update the location in the registry accordingly.

## Command Line
```ps
PS > .\8mb.ps1 -Source      [string]                   # the source file path.
               -Size        [uint64]                   # the destination file size.
               -SizeUnits   [KB|KiB|MB|MiB] (optional) # the destination file size units (MB is default).
               -Scale       [float]         (optional) # the destination resolution scale.
               -FPS         [float]         (optional) # the destination FPS.
               -Destination [string]        (optional) # the destination file path.
               -NoUpdates   [switch]        (optional) # disables the auto-updater on start.
```

# Example
```ps
PS > .\8mb.ps1 a.mp4 8 MB 0.5 24
8mb PowerShell

Source ===================================

Path -- : a.mp4
Size -- : 205,834 KiB (210,774,113 bytes)
Scale - : 1 (2560x1072)
FPS --- : 60 FPS

Destination ==============================

Path -- : a.8mb.mp4
Size -- : 7,813 KiB (8,000,000 bytes)
Scale - : 0.5 (1280x536)
FPS --- : 24 FPS

Starting transcode at 08/02/2024 03:09:36. Enter CTRL+C to cancel.

Pass 1: Video: 881 Kbps. Audio: 151 Kbps.
        Transcoding using 12 CPU cores...
        Compressed to 7,620 KiB (7,802,745 bytes).

Finished at 08/02/2024 03:09:47 in 11.1135412 seconds after 1 pass.
```
