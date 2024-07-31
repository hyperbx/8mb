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

$work = $PSScriptRoot
$ffmpeg = "${work}\ffmpeg.exe"
$ffprobe = "${work}\ffprobe.exe"
$isWaitForUserInput = $Shell -or $Prompt

echo "8mb PowerShell"
echo ""

function OnExit()
{
    if (!$isWaitForUserInput)
    {
        return
    }

    echo ""
    echo "Press any key to continue..."

    [void][System.Console]::ReadKey($true)
}

if (!(Test-Path $ffmpeg))
{
    echo "ffmpeg not found!"
    echo "Please download the Windows binary from https://ffbinaries.com/downloads and extract it into the script directory."
    OnExit
    exit -1
}

if (!(Test-Path $ffprobe))
{
    echo "ffprobe not found!"
    echo "Please download the Windows binary from https://ffbinaries.com/downloads and extract it into the script directory."
    OnExit
    exit -1
}

if (!(Test-Path $Source))
{
    echo "File not found: $Source"
    OnExit
    exit -1
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
        OnExit
        exit -1
    }
}

function GetSizeBytes()
{
    return (GetSizeKilobytes) * 1024
}

function GetDuration()
{
    & $ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $Source
}

function GetFrameRate()
{
    $result = & $ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate $Source
    $split = $result -split '/'
    
    return [Double]$split[0] / [Double]$split[1]
}

function Transcode([Int32]$bitrate)
{
    & $ffmpeg -y -hide_banner -loglevel error -i $Source -filter:v fps=$FPS -b $bitrate -cpu-used [Environment]::ProcessorCount -c:a copy $Destination
}

function PromptSize()
{
    $result = Read-Host -Prompt "Enter destination size"

    if ([string]::IsNullOrEmpty($result))
    {
        return PromptSize
    }

    if ([int]::TryParse($result, [ref]$null))
    {
        return [UInt32]$result
    }

    return PromptSize
}

function PromptSizeUnits()
{
    $result = Read-Host -Prompt "Enter destination size units (KB/MB)"

    if ([string]::IsNullOrEmpty($result))
    {
        return PromptSizeUnits
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

    return PromptSizeUnits
}

function PromptFPS()
{
    $sourceFPS = GetFrameRate
    $result = Read-Host -Prompt "Enter destination FPS (default: ${sourceFPS})"

    if ([string]::IsNullOrEmpty($result))
    {
        return $sourceFPS
    }

    if ([int]::TryParse($result, [ref]$null))
    {
        return [UInt32]$result
    }

    return PromptFPS
}

if ($Prompt)
{
    $Size = PromptSize
    $SizeUnits = PromptSizeUnits
    $FPS = PromptFPS

    echo ""
}

if ($Size -le 0)
{
    echo "Invalid destination size: $Size $SizeUnits"
    OnExit
    exit -1
}

if ($FPS -le 0)
{
    $FPS = GetFrameRate
}

if ([string]::IsNullOrEmpty($Destination))
{
    $Destination = "$([System.IO.Path]::GetFileNameWithoutExtension($Source)).${Size}$($SizeUnits.ToLower()).mp4"
}

$tolerance = 10
$toleranceThreshold = 1 + ($tolerance / 100)

$sourceSizeB = (Get-Item $Source).Length
$destSizeKB = GetSizeKilobytes
$destSizeB = GetSizeBytes
$sourceFPS = GetFrameRate
$duration = GetDuration
$bitrateAbs = $destSizeB / $duration
$bitrate = [math]::Round($bitrateAbs + ($bitrateAbs * ($FPS / $sourceFPS)))

if ($destSizeB -gt $sourceSizeB)
{
    echo "The destination size cannot be larger than the source file size."
    OnExit
    exit -1
}

if ($duration -le 0)
{
    echo "Invalid video duration: $duration"
    OnExit
    exit -1
}

echo "Source Path ------ : $Source"
echo "Destination Path - : $Destination"
echo "Source Size ------ : $(($sourceSizeB / 1024).ToString("N0")) KB ($($sourceSizeB.ToString("N0")) bytes)"
echo "Destination Size - : $($destSizeKB.ToString("N0")) KB ($($destSizeB.ToString("N0")) bytes)"

if ($FPS -ne $sourceFPS)
{
    echo "Source FPS ------- : $sourceFPS FPS"
    echo "Destination FPS -- : $FPS FPS"
}

$startTime = Get-Date

echo ""
echo "Starting transcode at ${startTime}. Enter CTRL+C to cancel."
echo ""

$factor = 0
$attempt = 0

while ($factor -gt $toleranceThreshold -or $factor -lt 1)
{
    $attempt += 1

    if ($factor -le 0)
    {
        $factor = 1
    }

    $bitrate = [math]::Round($bitrate * $factor)
    $bitrateF = "$(($bitrate / 1024).ToString("N0")) Kbps"

    if ($bitrate -le 1024)
    {
        echo "Attempt ${attempt}: attempted to encode at $bitrate bps, aborting..."
        break
    }

    echo "Attempt ${attempt}: transcoding source file at $bitrateF using $([Environment]::ProcessorCount) CPU cores..."

    Transcode $bitrate

    if ($newSizeB -eq (Get-Item $Destination).Length)
    {
        echo "Attempt ${attempt}: cannot compress any smaller than $(($newSizeB / 1024).ToString("N0")) KB."
        break
    }

    $newSizeB = (Get-Item $Destination).Length
    $percent = (100 / $destSizeB) * $newSizeB
    $factor = 100 / $percent
    
    echo "Attempt ${attempt}: compressed $(($sourceSizeB / 1024).ToString("N0")) KB down to $(($newSizeB / 1024).ToString("N0")) KB at $bitrateF."
}

$endTime = Get-Date

echo ""
echo "Finished at $endTime in $(($endTime - $startTime).TotalSeconds) seconds with $attempt attempt(s)."
OnExit