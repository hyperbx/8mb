# 8mb PowerShell
# Written by Hyper, original by Matthew Baggett

param
(
    [string]$Source,
    [uint64]$Size,
    [string]$SizeUnits = "MB",
    [float]$Scale = 1.0,
    [float]$FPS,
    [string]$Destination,
    [switch]$Shell,
    [switch]$Prompt,
    [switch]$NoUpdates,
    [switch]$NoAudioTrackMerge
)

$isAudioTrackMerge = !$NoAudioTrackMerge

$ffmpeg  = "${PSScriptRoot}\ffmpeg.exe"
$ffprobe = "${PSScriptRoot}\ffprobe.exe"

function Refresh()
{
    Clear-Host
    echo "8mb PowerShell"
    echo ""
}

Refresh

function Leave([int32]$exitCode = 0)
{
    if (!($Shell -or $Prompt))
    {
        exit $exitCode
    }

    echo ""
    echo "Press any key to exit..."

    [System.Console]::ReadKey($true)

    exit $exitCode
}

# Check for updates to the script.
# This is probably a bit of a stretch existing for this thing.
function CheckForUpdates()
{
    if (!(Test-Connection -ComputerName "github.com" -Count 1 -Quiet))
    {
        return
    }
    
    $response = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/hyperbx/8mb/main/8mb.ps1"

    $currentScript = [System.IO.File]::ReadAllText($PSCommandPath)
    $remoteScript  = $response.Content

    if ($currentScript -eq $remoteScript)
    {
        return
    }

    $verify = "# 8mb PowerShell"

    # Verify that the remote script was downloaded successfully.
    if (!($remoteScript.StartsWith($verify) -and $remoteScript.EndsWith($verify)))
    {
        return
    }

    function PromptUpdate()
    {
        $result = Read-Host "An update is available, would you like to download it? [Y|N]"
        $result = $result.ToLower()

        if ($result -eq "n")
        {
            Refresh
            return
        }
        elseif ($result -eq "y")
        {
            [System.IO.File]::WriteAllText($PSCommandPath, $remoteScript)

            $args = "-ExecutionPolicy Bypass -File `"${PSCommandPath}`" `"${Source}`" $Size $SizeUnits $Scale $FPS `"${Destination}`""

            if ($Shell)
            {
                $args += "-Shell"
            }

            if ($Prompt)
            {
                $args += "-Prompt"
            }

            Clear-Host
            Start-Process powershell -ArgumentList $args -NoNewWindow
            
            exit
        }
        else
        {
            PromptUpdate
        }
    }

    PromptUpdate
}

if (!$NoUpdates)
{
    CheckForUpdates
}

if (!(Test-Path $ffmpeg))
{
    try
    {
        $ffmpeg = (Get-Command ffmpeg -ErrorAction Stop).Path
    }
    catch
    {
        echo "ffmpeg not found!"
        echo "Please download the Windows binary from https://ffbinaries.com/downloads and extract it into the script directory."
        Leave -1
    }
}

if (!(Test-Path $ffprobe))
{
    try
    {
        $ffprobe = (Get-Command ffprobe -ErrorAction Stop).Path
    }
    catch
    {
        echo "ffprobe not found!"
        echo "Please download the Windows binary from https://ffbinaries.com/downloads and extract it into the script directory."
        Leave -1
    }
}

if (!(Test-Path $Source))
{
    echo "File not found: $Source"
    Leave -1
}

# Gets the size of the destination file in bytes.
function GetDestinationSize()
{
    $units = $SizeUnits.ToLower()

    if ($units -eq "kb")
    {
        return $Size * 1000
    }
    elseif ($units -eq "kib")
    {
        return $Size * 1024
    }
    elseif ($units -eq "mb")
    {
        return $Size * 1000 * 1000
    }
    elseif ($units -eq "mib")
    {
        return $Size * 1024 * 1024
    }

    echo "Invalid destination size: $Size $SizeUnits"

    Leave -1
}

# Gets the total bitrate of all audio tracks in the source file.
function GetSourceAudioBitrate()
{
    $bitrates = & $ffprobe -v error `
                           -select_streams a `
                           -show_entries stream=bit_rate `
                           -of default=noprint_wrappers=1:nokey=1 `
                           $Source

    $bitrates = $bitrates -split "`n" | ForEach-Object { [uint64]$_ }

    return ($bitrates | Measure-Object -Sum).Sum
}

# Gets the total number of audio tracks in the source file.
function GetSourceAudioTrackCount()
{
    if (!$isAudioTrackMerge)
    {
        return 1
    }

    $tracks = & $ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 $Source

    return ($tracks -split "`n").Count
}

# Gets the duration of the source file in seconds.
function GetSourceDuration()
{
    & $ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $Source
}

# Gets the frame rate of the source file.
function GetSourceFPS()
{
    $result = & $ffprobe -v error `
                         -select_streams v `
                         -of default=noprint_wrappers=1:nokey=1 `
                         -show_entries stream=avg_frame_rate `
                         $Source

    $split = $result -split '/'
    
    return [double]$split[0] / [double]$split[1]
}

# Gets the resolution of the source file.
function GetSourceResolution()
{
    [string]$result = & $ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of json $Source
    $json = ConvertFrom-Json $result

    return ($json.streams[0].width, $json.streams[0].height)
}

# Gets the resolution of the source file scaled to the user value.
function GetSourceResolutionScaled()
{
    function Even([uint32]$value)
    {
        if ($value % 2 -ne 0)
        {
            return $value + 1
        }

        return $value
    }
    
    [uint32]$width, [uint32]$height = (GetSourceResolution) -split ','

    $width = Even ($width * $Scale)
    $height = Even ($height * $Scale)

    return @($width, $height)
}

function Transcode([uint64]$videoBitrate, [uint64]$audioBitrate)
{
    [uint32]$width, [uint32]$height = (GetSourceResolutionScaled) -split ','

    $audioParams = @()
    $audioTrackCount  = GetSourceAudioTrackCount
    if ($audioTrackCount -gt 0) {
        $audioMergeFilter = ""
        
        # Create complex filter for merging all audio tracks.
        for ($i = 0; $i -lt $audioTrackCount; $i++)
        {
            $audioMergeFilter += "[0:a:${i}]"
        }
        
        $audioMergeFilter += "amerge=inputs=${audioTrackCount}[aout]"
        
        $audioParams = @("-filter_complex", $audioMergeFilter, "-map", "`"[aout]`"")
    }

    & $ffmpeg -y `
              -hide_banner `
              -loglevel error `
              -i $Source `
              -cpu-used [Environment]::ProcessorCount `
              $audioParams `
              -map 0:v `
              -filter:v "fps=${FPS},scale=${width}:${height}:flags=lanczos" `
              -b:v $videoBitrate `
              -c:a aac `
              -b:a $audioBitrate `
              $Destination
}

# Prompt the user for the destination size in either kilobytes or megabytes.
function PromptDestinationSize()
{
    $result = Read-Host -Prompt "Enter destination size"

    if ([string]::IsNullOrEmpty($result))
    {
        return PromptDestinationSize
    }

    if ([uint64]::TryParse($result, [ref]$null))
    {
        return [uint64]$result
    }

    return PromptDestinationSize
}

# Prompt the user for the units for the destination size.
function PromptDestinationSizeUnits()
{
    $result = Read-Host -Prompt "Enter destination size units [KB|KiB|MB|MiB]"

    if ([string]::IsNullOrEmpty($result))
    {
        return PromptDestinationSizeUnits
    }

    $result = $result.ToLower()

    if ($result -eq "kb" -or $result -eq "kib" -or $result -eq "mb" -or $result -eq "mib")
    {
        return $result
    }

    return PromptDestinationSizeUnits
}

# Prompt the user for the destination scale.
function PromptDestinationScale()
{
    $input = Read-Host -Prompt "Enter destination scale [default: 1.0]"

    if ([string]::IsNullOrEmpty($input))
    {
        return 1.0
    }

    [float]$result = 0
    
    if ([float]::TryParse($input, `
        [System.Globalization.NumberStyles]::Float, `
        [System.Globalization.CultureInfo]::CurrentCulture, `
        [ref]$result))
    {
        return $result
    }

    return PromptDestinationScale
}

# Prompt the user for the destination frame rate.
function PromptDestinationFPS()
{
    $sourceFPS = GetSourceFPS
    $input = Read-Host -Prompt "Enter destination FPS [default: ${sourceFPS}]"

    if ([string]::IsNullOrEmpty($input))
    {
        return $sourceFPS
    }

    [float]$result = 0

    if ([float]::TryParse($input, `
        [System.Globalization.NumberStyles]::Float, `
        [System.Globalization.CultureInfo]::CurrentCulture, `
        [ref]$result))
    {
        return $result
    }

    return PromptDestinationFPS
}

function PromptDestinationAudioTracks()
{
    $audioTrackCount = GetSourceAudioTrackCount

    if ($audioTrackCount -le 1)
    {
        return 1
    }

    $tracksPlural = "tracks"
    $itemPlural = "them"

    if (($audioTrackCount - 1) -eq 1)
    {
        $tracksPlural = "track"
        $itemPlural = "it"
    }

    $result = Read-Host -Prompt "Found $($audioTrackCount - 1) additional audio ${tracksPlural}, would you like to merge ${itemPlural}? [Y|N]"
    $result = $result.ToLower()

    if ($result -eq "y")
    {
        return 1
    }
    elseif ($result -eq "n")
    {
        return 0
    }

    return PromptDestinationAudioTracks
}

# Prompt the user to fill out the destination size and frame rate.
if ($Prompt)
{
    $Size      = PromptDestinationSize
    $SizeUnits = PromptDestinationSizeUnits
    $Scale     = PromptDestinationScale
    $FPS       = PromptDestinationFPS

    echo ""
}

if ($Prompt -or $Shell)
{
    $isAudioTrackMerge = PromptDestinationAudioTracks

    Refresh
}

# Throw if the destination size is less than or equal to zero.
if ($Size -le 0)
{
    echo "Invalid destination size: $Size $SizeUnits"
    Leave -1
}

# Throw if the destination scale is less than or equal to zero.
if ($Scale -le 0)
{
    echo "Invalid destination scale: $Scale"
    Leave -1
}

$sourceFPS = GetSourceFPS

if ($FPS -le 0)
{
    # Ensure the destination frame rate is greater than zero.
    $FPS = $sourceFPS
}
else
{
    # Ensure the destination frame rate is less than the source frame rate.
    $FPS = [Math]::Min($FPS, $sourceFPS)
}

# Create temporary destination file name, if none was provided.
if ([string]::IsNullOrEmpty($Destination))
{
    $Destination = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($Source), `
        "$([System.IO.Path]::GetFileNameWithoutExtension($Source)).${Size}$($SizeUnits.ToLower()).mp4")
}

$sourceSizeBytes = (Get-Item $Source).Length
$destSizeBytes = GetDestinationSize
$duration = GetSourceDuration

# Throw if the destination size is greater than the source size.
if ($destSizeBytes -gt $sourceSizeBytes)
{
    echo "The destination size cannot be larger than the source size."
    Leave -1
}

# Throw if the video duration is less than or equal to zero.
if ($duration -le 0)
{
    echo "Invalid video duration: $duration"
    Leave -1
}

function PrintInfo([string]$path, [uint64]$sizeBytes, [float]$scale, [float]$fps)
{
    [uint32]$width, [uint32]$height = (GetSourceResolutionScaled) -split ','

    echo "Path -- : $path"
    echo "Size -- : $(($sizeBytes / 1024).ToString("N0")) KiB ($($sizeBytes.ToString("N0")) bytes)"
    echo "Scale - : $scale (${width}x${height})"
    echo "FPS --- : $fps FPS"
}

echo "Source ==================================="
echo ""
PrintInfo $Source $sourceSizeBytes 1.0 $sourceFPS
echo ""

echo "Destination =============================="
echo ""
PrintInfo $Destination $destSizeBytes $Scale $FPS

$startTime = Get-Date

echo ""
echo "Starting transcode at ${startTime}. Enter CTRL+C to cancel."
echo ""

$tolerance = 10
$toleranceThreshold = 1 + ($tolerance / 100)
$pass = 0
$factor = 0
$isReachedOptimalCompression = 0

# Compute destination bitrate based on compression ratio of target size, with a minimum of 64 Kbps.
$destAudioBitrate = (65535 + ((GetSourceAudioBitrate) - 65535) * $destSizeBytes / $sourceSizeBytes) * (GetSourceAudioTrackCount)

# Precompute the destination bitrate and subtract the audio bitrate
# to get a closer estimate and require fewer attempts to transcode.
$destVideoBitrate = [Math]::Max($destAudioBitrate, ($destSizeBytes * 8) / $duration) - $destAudioBitrate

while ($factor -gt $toleranceThreshold -or $factor -lt 1)
{
    $pass += 1

    # Ensure the bitrate factor never reaches zero or below.
    if ($factor -le 0)
    {
        $factor = 1
    }

    # Multiply bitrate by factor to increase/decrease file size on further passes.
    $destVideoBitrate = [Math]::Round($destVideoBitrate * $factor)

    $destAudioBitrateF = "$(($destAudioBitrate / 1024).ToString("N0")) Kbps"
    $destVideoBitrateF = "$(($destVideoBitrate / 1024).ToString("N0")) Kbps"

    $passPrefix      = "Pass ${pass}:"
    $passPrefixBlank = ' ' * $passPrefix.Length

    # ffmpeg doesn't seem to like bitrates lower than 1 Kbps, so abort if this ever happens.
    # 0 audio bitrate means there is no audio stream.
    if ($destVideoBitrate -le 1024 -or ($destAudioBitrate -ne 0 -and $destAudioBitrate -le 1024))
    {
        echo "$passPrefix Attempted to transcode below 1 Kbps, aborting..."
        break
    }

    echo "$passPrefix Video: ${destVideoBitrateF}. Audio: ${destAudioBitrateF}."
    echo "$passPrefixBlank Transcoding using $([Environment]::ProcessorCount) CPU cores..."

    Transcode $destVideoBitrate $destAudioBitrate

    # Signal to break if transcoded to the same file size.
    if ($newSizeBytes -eq (Get-Item $Destination).Length)
    {
        $isReachedOptimalCompression = 1
    }

    $newSizeBytes = (Get-Item $Destination).Length
    $percent = (100 / $destSizeBytes) * $newSizeBytes
    $factor = (100 / $percent)
    
    echo "$passPrefixBlank Compressed to $(($newSizeBytes / 1024).ToString("N0")) KiB ($($newSizeBytes.ToString("N0")) bytes)."

    if ($isReachedOptimalCompression)
    {
        break
    }
}

$passPlural = "passes"

# Most pointless code in this script.
if ($pass -eq 1)
{
    $passPlural = "pass"
}

$endTime = Get-Date

echo ""
echo "Finished at $endTime in $(($endTime - $startTime).TotalSeconds) seconds after $pass ${passPlural}."

Leave

# 8mb PowerShell