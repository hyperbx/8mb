param
(
    [String]$Source,
    [UInt32]$Size,
    [String]$SizeUnits = "MB",
    [Single]$Scale = 1.0,
    [UInt32]$FPS,
    [String]$Destination,
    [Switch]$Shell,
    [Switch]$Prompt
)

$ffmpeg  = "${PSScriptRoot}\ffmpeg.exe"
$ffprobe = "${PSScriptRoot}\ffprobe.exe"

echo "8mb PowerShell"
echo ""

function Leave([Int32]$exitCode = 0)
{
    if (!($Shell -or $Prompt))
    {
        exit $exitCode
    }

    echo ""
    echo "Press any key to exit..."

    [void][System.Console]::ReadKey($true)

    exit $exitCode
}

if (!(Test-Path $ffmpeg))
{
    echo "ffmpeg not found!"
    echo "Please download the Windows binary from https://ffbinaries.com/downloads and extract it into the script directory."
    Leave -1
}

if (!(Test-Path $ffprobe))
{
    echo "ffprobe not found!"
    echo "Please download the Windows binary from https://ffbinaries.com/downloads and extract it into the script directory."
    Leave -1
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
    $bitrates = & $ffprobe -v error -select_streams a -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 $Source
    $bitrates = $bitrates -split "`n" | ForEach-Object { [Int32]$_ }

    return ($bitrates | Measure-Object -Sum).Sum
}

# Gets the total number of audio tracks in the source file.
function GetSourceAudioTrackCount()
{
    $tracks = & $ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 $Source

    return ($tracks -split "`n").Count
}

# Gets the average bitrate across all audio tracks.
function GetSourceAudioBitrateAverage()
{
    return (GetSourceAudioBitrate) / (GetSourceAudioTrackCount)
}

# Gets the duration of the source file in seconds.
function GetSourceDuration()
{
    & $ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $Source
}

# Gets the frame rate of the source file.
function GetSourceFPS()
{
    $result = & $ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate $Source
    $split = $result -split '/'
    
    return [Double]$split[0] / [Double]$split[1]
}

# Gets the resolution of the source file.
function GetSourceResolution()
{
    return & $ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 $Source
}

function Transcode([UInt32]$videoBitrate, [UInt32]$audioBitrate)
{
    [UInt32]$width, [UInt32]$height = (GetSourceResolution) -split ','
    
    # Set resolution scale.
    $width  *= $Scale
    $height *= $Scale

    & $ffmpeg -y -hide_banner -loglevel error -i $Source -cpu-used [Environment]::ProcessorCount -filter:v "fps=${FPS},scale=${width}:${height}:flags=lanczos" -b:v $videoBitrate -c:a aac -b:a $audioBitrate $Destination
}

# Prompt the user for the destination size in either kilobytes or megabytes.
function PromptDestinationSize()
{
    $result = Read-Host -Prompt "Enter destination size"

    if ([string]::IsNullOrEmpty($result))
    {
        return PromptDestinationSize
    }

    if ([int]::TryParse($result, [ref]$null))
    {
        return [UInt32]$result
    }

    return PromptDestinationSize
}

# Prompt the user for the units for the destination size.
function PromptDestinationSizeUnits()
{
    $result = Read-Host -Prompt "Enter destination size units (KB|KiB|MB|MiB)"

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
    $result = Read-Host -Prompt "Enter destination scale (default: 1.0)"

    if ([string]::IsNullOrEmpty($result))
    {
        return 1.0
    }

    if ([float]::TryParse($result, [ref]$null))
    {
        return [Single]$result
    }

    return PromptDestinationScale
}

# Prompt the user for the destination frame rate.
function PromptDestinationFPS()
{
    $sourceFPS = GetSourceFPS
    $result = Read-Host -Prompt "Enter destination FPS (default: ${sourceFPS})"

    if ([string]::IsNullOrEmpty($result))
    {
        return $sourceFPS
    }

    if ([int]::TryParse($result, [ref]$null))
    {
        return [UInt32]$result
    }

    return PromptDestinationFPS
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

# Throw if the destination FPS is greater than the source FPS.
if ($FPS -gt $sourceFPS)
{
    echo "The destination FPS cannot be larger than the source FPS."
    Leave -1
}

# Ensure the destination frame rate is greater than zero.
if ($FPS -le 0)
{
    $FPS = $sourceFPS
}

# Create temporary destination file name, if none was provided.
if ([string]::IsNullOrEmpty($Destination))
{
    $Destination = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($Source), "$([System.IO.Path]::GetFileNameWithoutExtension($Source)).${Size}$($SizeUnits.ToLower()).mp4")
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

function PrintInfo([String]$path, [UInt64]$sizeBytes, [Single]$scale, [UInt32]$fps)
{
    [UInt32]$width, [UInt32]$height = (GetSourceResolution) -split ','

    echo "Path -- : $path"
    echo "Size -- : $(($sizeBytes / 1024).ToString("N0")) KiB ($($sizeBytes.ToString("N0")) bytes)"
    echo "Scale - : $scale ($($width * $scale)x$($height * $scale))"
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
$destAudioBitrate = 65535 + ((GetSourceAudioBitrateAverage) - 65535) * $destSizeBytes / $sourceSizeBytes

# Precompute the destination bitrate and subtract the audio bitrate
# to get a closer estimate and require fewer attempts to transcode.
$destVideoBitrate = [math]::Max($destAudioBitrate, ($destSizeBytes * 8) / $duration) - $destAudioBitrate

while ($factor -gt $toleranceThreshold -or $factor -lt 1)
{
    $pass += 1

    # Ensure the bitrate factor never reaches zero or below.
    if ($factor -le 0)
    {
        $factor = 1
    }

    # Multiply bitrate by factor to increase/decrease file size on further passes.
    $destVideoBitrate = [math]::Round($destVideoBitrate * $factor)

    $destAudioBitrateF = "$(($destAudioBitrate / 1024).ToString("N0")) Kbps"
    $destVideoBitrateF = "$(($destVideoBitrate / 1024).ToString("N0")) Kbps"

    $passPrefix      = "Pass ${pass}:"
    $passPrefixBlank = ' ' * $passPrefix.Length

    # ffmpeg doesn't seem to like bitrates lower than 1 Kbps, so abort if this ever happens.
    if ($destVideoBitrate -le 1024)
    {
        echo "$passPrefix Attempted to transcode video at $destVideoBitrate bps, aborting..."
        break
    }

    echo "$passPrefix Transcoding using $([Environment]::ProcessorCount) CPU cores..."
    echo "$passPrefixBlank Video: ${destVideoBitrateF}, Audio: ${destAudioBitrateF}"

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