param
(
    [String]$Source,
    [UInt32]$Size,
    [String]$SizeUnits = "MB",
    [String]$Destination = ""
)

echo "8mb PowerShell"
echo ""

if (!(Test-Path ".\ffmpeg.exe"))
{
    echo "ffmpeg not found!"
    echo "Please download the Windows binary from https://ffbinaries.com/downloads and extract it into the script directory."
    exit -1
}

if (!(Test-Path ".\ffprobe.exe"))
{
    echo "ffprobe not found!"
    echo "Please download the Windows binary from https://ffbinaries.com/downloads and extract it into the script directory."
    exit -1
}

if (!(Test-Path $Source))
{
    echo "File not found: $Source"
    exit -1
}

if ($Size -le 0)
{
    echo "Invalid destination size: $Size $SizeUnits"
    exit -1
}

if ([string]::IsNullOrEmpty($Destination))
{
    $Destination = "$([System.IO.Path]::GetFileNameWithoutExtension($Source)).compressed.mp4"
}

function GetSizeKilobytes()
{
    $units = $SizeUnits.ToLower()

    if ($units -eq "kb")
    {
        return $Size
    }
    elseif ($units -eq "mb")
    {
        return $Size * 1024
    }
    else
    {
        echo "Invalid destination size: $Size $SizeUnits"
        exit -1
    }
}

function GetSizeBytes()
{
    return (GetSizeKilobytes) * 1024
}

function GetDuration()
{
    & .\ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $Source
}

function Transcode([Int32]$bitrate)
{
    & .\ffmpeg -y -hide_banner -loglevel error -i $Source -b $bitrate -cpu-used [Environment]::ProcessorCount -c:a copy $Destination
}

$tolerance = 10
$toleranceThreshold = 1 + ($tolerance / 100)

$sourceSizeB = (Get-Item $Source).Length
$destSizeKB = GetSizeKilobytes
$destSizeB = GetSizeBytes
$duration = GetDuration
$bitrate = [math]::Round($destSizeB / $duration)

if ($duration -le 0)
{
    echo "Invalid video duration: $duration"
    exit -1
}

echo "Source Path ------ : $Source"
echo "Destination Path - : $Destination"
echo "Source Size ------ : $(($sourceSizeB / 1024).ToString("N0")) KB ($($sourceSizeB.ToString("N0")) bytes)"
echo "Destination Size - : $($destSizeKB.ToString("N0")) KB ($($destSizeB.ToString("N0")) bytes)"
echo ""

$factor = 0
$attempt = 0

$startTime = Get-Date

echo "Starting transcode at ${startTime}."
echo ""

while ($factor -gt $toleranceThreshold -or $factor -lt 1)
{
    $attempt += 1

    if ($factor -le 0)
    {
        $factor = 1
    }

    $bitrate = [math]::Round($bitrate * $factor)
    $bitrateF = "$(($bitrate / 1024).ToString("N0")) Kbps"

    echo "Attempt ${attempt}: transcoding source file at $bitrateF using $([Environment]::ProcessorCount) CPU cores..."

    Transcode $bitrate

    $newSizeB = (Get-Item $Destination).Length
    $percent = (100 / $destSizeB) * $newSizeB
    $factor = 100 / $percent
    
    echo "Attempt ${attempt}: compressed $(($sourceSizeB / 1024).ToString("N0")) MB down to $(($newSizeB / 1024).ToString("N0")) MB at $bitrateF."
}

$endTime = Get-Date

echo ""
echo "Finished at $endTime in $(($endTime - $startTime).TotalSeconds) seconds with $attempt attempt(s)."