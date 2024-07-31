param
(
    [String]$Source,
    [UInt32]$Size,
    [String]$SizeUnits = "MB",
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
    elseif ($units -eq "mb")
    {
        return $Size * 1000 * 1000
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

function Transcode([Int32]$bitrate)
{
    & $ffmpeg -y -hide_banner -loglevel error -i $Source -filter:v fps=$FPS -b $bitrate -cpu-used [Environment]::ProcessorCount -c:a copy $Destination
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
    $result = Read-Host -Prompt "Enter destination size units (KB/MB)"

    if ([string]::IsNullOrEmpty($result))
    {
        return PromptDestinationSizeUnits
    }

    $result = $result.ToLower()

    if ($result.StartsWith("k") -or $result.StartsWith("m"))
    {
        if (!$result.EndsWith("b"))
        {
            return "${result}b"
        }
        
        return $result
    }

    return PromptDestinationSizeUnits
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
    $FPS       = PromptDestinationFPS

    echo ""
}

# Throw if the destination size is less than or equal to zero.
if ($Size -le 0)
{
    echo "Invalid destination size: $Size $SizeUnits"
    Leave -1
}

# Ensure the destination frame rate is greater than zero.
if ($FPS -le 0)
{
    $FPS = GetSourceFPS
}

# Create temporary destination file name, if none was provided.
if ([string]::IsNullOrEmpty($Destination))
{
    $Destination = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($Source), "$([System.IO.Path]::GetFileNameWithoutExtension($Source)).${Size}$($SizeUnits.ToLower()).mp4")
}

$tolerance = 10
$toleranceThreshold = 1 + ($tolerance / 100)

$duration = GetSourceDuration

$sourceSizeBytes = (Get-Item $Source).Length
$sourceAudioBitrateAvg = (GetSourceAudioBitrate) / (GetSourceAudioTrackCount)
$sourceFPS = GetSourceFPS

$destSizeBytes = GetDestinationSize
$destSizeBits  = $destSizeBytes * 8

# Precompute the destination bitrate and subtract the average
# of the total audio bitrate to get a closer estimate and require
# fewer attempts to transcode.
$destBitrate = [math]::Max($sourceAudioBitrateAvg, [math]::Round($destSizeBits / $duration) - $sourceAudioBitrateAvg)

# Throw if the destination size is greater than the source file size.
if ($destSizeBytes -gt $sourceSizeBytes)
{
    echo "The destination size cannot be larger than the source file size."
    Leave -1
}

# Throw if the video duration is less than or equal to zero.
if ($duration -le 0)
{
    echo "Invalid video duration: $duration"
    Leave -1
}

echo "Source Path ------ : $Source"
echo "Destination Path - : $Destination"
echo "Source Size ------ : $(($sourceSizeBytes / 1000).ToString("N0")) KB ($($sourceSizeBytes.ToString("N0")) bytes)"
echo "Destination Size - : $(($destSizeBytes / 1000).ToString("N0")) KB ($($destSizeBytes.ToString("N0")) bytes)"

if ($FPS -ne $sourceFPS)
{
    echo "Source FPS ------- : $sourceFPS FPS"
    echo "Destination FPS -- : $FPS FPS"
}

$startTime = Get-Date

echo ""
echo "Starting transcode at ${startTime}. Enter CTRL+C to cancel."
echo ""

$attempt = 0
$factor = 0

while ($factor -gt $toleranceThreshold -or $factor -lt 1)
{
    $attempt += 1

    # Ensure the bitrate factor never reaches zero or below.
    if ($factor -le 0)
    {
        $factor = 1
    }

    # Multiply bitrate by factor to increase/decrease file size on future attempts.
    $destBitrate  = [math]::Round($destBitrate * $factor)
    $destBitrateF = "$(($destBitrate / 1000).ToString("N0")) Kbps"

    $attemptPrefix      = "Attempt ${attempt}:"
    $attemptPrefixBlank = ' ' * $attemptPrefix.Length

    # ffmpeg doesn't seem to like bitrates lower than 1 Kbps, so abort if this ever happens.
    if ($destBitrate -le 1024)
    {
        echo "$attemptPrefix Attempted to encode at $destBitrate bps, aborting..."
        break
    }

    echo "$attemptPrefix Transcoding at $destBitrateF using $([Environment]::ProcessorCount) CPU cores..."

    Transcode $destBitrate

    # Break if attempted to transcode to the same file size.
    if ($newSizeB -eq (Get-Item $Destination).Length)
    {
        echo "$attemptPrefixBlank Cannot compress any smaller than $(($newSizeB / 1000).ToString("N0")) KB."
        break
    }

    $newSizeB = (Get-Item $Destination).Length
    $percent  = (100 / $destSizeBytes) * $newSizeB
    $factor   = (100 / $percent)
    
    echo "$attemptPrefixBlank Compressed to $(($newSizeB / 1000).ToString("N0")) KB."
}

$attemptPlural = "attempts"

# Most pointless code in this script.
if ($attempt -eq 1)
{
    $attemptPlural = "attempt"
}

$endTime = Get-Date

echo ""
echo "Finished at $endTime in $(($endTime - $startTime).TotalSeconds) seconds after $attempt ${attemptPlural}."

Leave