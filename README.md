# 8mb
8MB video compression PowerShell script for ffmpeg.

# Prerequisites
- Windows PowerShell
- [ffmpeg](https://ffbinaries.com/downloads)
- [ffprobe](https://ffbinaries.com/downloads)

# Usage
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

Starting transcode at 07/31/2024 11:51:23.

Attempt 1: transcoding source file at 135 Kbps using 12 CPU cores...
Attempt 1: compressed 205,834 MB down to 3,488 MB at 135 Kbps.
Attempt 2: transcoding source file at 318 Kbps using 12 CPU cores...
Attempt 2: compressed 205,834 MB down to 3,830 MB at 318 Kbps.
Attempt 3: transcoding source file at 680 Kbps using 12 CPU cores...
Attempt 3: compressed 205,834 MB down to 6,447 MB at 680 Kbps.
Attempt 4: transcoding source file at 863 Kbps using 12 CPU cores...
Attempt 4: compressed 205,834 MB down to 7,819 MB at 863 Kbps.

Finished at 07/31/2024 11:53:36 in 132.8912433 seconds with 4 attempt(s).
```