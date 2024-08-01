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
PS > .\8mb.ps1 -Source [string]
               -Size [uint64]
               -SizeUnits [KB|KiB|MB (default)|MiB] (optional)
               -Scale [float] (optional)
               -FPS [float] (optional)
               -Destination [string] (optional)
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

Starting transcode at 08/01/2024 16:29:28. Enter CTRL+C to cancel.

Pass 1: Transcoding using 12 CPU cores...
        Video: 963 Kbps, Audio: 68 Kbps
        Compressed to 7,597 KiB (7,779,020 bytes).

Finished at 08/01/2024 16:29:39 in 10.9649922 seconds after 1 pass.
```
