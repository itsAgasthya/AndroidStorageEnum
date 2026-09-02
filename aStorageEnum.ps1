param (
    [Parameter(Position=0)]
    [string]$PackageName
)

Write-Host "        _____ _                               ______                   " -ForegroundColor Cyan
Write-Host "       / ____| |                             |  ____|                  " -ForegroundColor Cyan
Write-Host "  __ _| (___ | |_ ___  _ __ __ _  __ _  ___  | |__   _ __  _   _ _ __ ___ " -ForegroundColor Cyan
Write-Host " / _\` |\___ \| __/ _ \| '__/ _\` |/ _\` |/ _ \ |  __| | '_ \| | | | '_ \ _ \" -ForegroundColor Cyan
Write-Host "| (_| |____) | || (_) | | | (_| | (_| |  __/ | |____| | | | |_| | | | | | |" -ForegroundColor Cyan
Write-Host " \__,_|_____/ \__\___/|_|  \__,_|\__, |\___| |______|_| |_|\__,_|_| |_| |_|" -ForegroundColor Cyan
Write-Host "                                  __/ |                                    " -ForegroundColor Cyan
Write-Host "                                 |___/                                     " -ForegroundColor Cyan
Write-Host ""

Write-Host "Tip: Make sure your device is connected and accessible via ADB." -ForegroundColor Yellow
Write-Host "Tip: Ensure you have grepwords.txt in the same directory for keyword search." -ForegroundColor Yellow
Write-Host ""

# Check adb
if (!(Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host "The script requires 'adb' to be installed and in PATH." -ForegroundColor Red
    exit
}

if ([string]::IsNullOrWhiteSpace($PackageName)) {
    $PackageName = Read-Host "Enter the Android package name (e.g., com.example.app)"
}

if ([string]::IsNullOrWhiteSpace($PackageName)) {
    Write-Host "Package name cannot be empty." -ForegroundColor Red
    exit
}

Write-Host "[+] Checking device connection..." -ForegroundColor Yellow
$adbDevices = adb devices
if (($adbDevices -match "device$").Count -eq 0) {
    Write-Host "No connected device found. Please connect a device or start an emulator." -ForegroundColor Red
    exit
}

Write-Host "[+] Enumerating files from Android device for $PackageName!" -ForegroundColor Yellow

# Check for root
$isRooted = $false
$suCheck = adb shell su -c id 2>&1
if ($suCheck -match "uid=0\(root\)") {
    $isRooted = $true
}

$tarFileName = "$PackageName`_data.tar.gz"

if ($isRooted) {
    Write-Host "[+] Root access detected! Using su..." -ForegroundColor Green
    $tarCmd = "su -c 'tar -czf /data/local/tmp/$tarFileName -C /data/data/$PackageName .'"
    $cleanupCmd = "su -c 'rm /data/local/tmp/$tarFileName'"
} else {
    Write-Host "[-] Device doesn't seem to have 'su' access. Trying run-as..." -ForegroundColor Red
    $runAsCheck = adb shell run-as $PackageName id 2>&1
    if ($runAsCheck -match "not debuggable" -or $runAsCheck -match "not found" -or $runAsCheck -match "unknown package") {
        Write-Host "[-] run-as failed. The application might not be debuggable, and device is not rooted." -ForegroundColor Red
        Write-Host "Exiting..." -ForegroundColor Red
        exit
    }
    Write-Host "[+] run-as successful!" -ForegroundColor Green
    $tarCmd = "run-as $PackageName sh -c 'tar -czf /data/local/tmp/$tarFileName .'"
    $cleanupCmd = "run-as $PackageName sh -c 'rm /data/local/tmp/$tarFileName'"
}

Write-Host "[+] Archiving application data on device..." -ForegroundColor Yellow
adb shell $tarCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "[-] Failed to archive data on device." -ForegroundColor Red
    exit
}

Write-Host "[+] Downloading application data to local machine..." -ForegroundColor Yellow
adb pull /data/local/tmp/$tarFileName .
if (-not (Test-Path $tarFileName)) {
    Write-Host "[-] Failed to download data." -ForegroundColor Red
    adb shell $cleanupCmd
    exit
}

Write-Host "[+] Cleaning up temporary files on device..." -ForegroundColor Yellow
adb shell $cleanupCmd

Write-Host "[+] Making directory with the package name" -ForegroundColor Yellow
$extractPath = "$PackageName\files"
New-Item -ItemType Directory -Force -Path $extractPath | Out-Null

Write-Host "[+] Extracting files..." -ForegroundColor Yellow
# Using tar which is built into Windows 10/11
tar -xzf $tarFileName -C $extractPath

# PowerShell equivalent of strings
function Get-Strings {
    param([string]$Path)
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $currentString = [System.Text.StringBuilder]::new()
        $result = [System.Collections.Generic.List[string]]::new()
        foreach ($b in $bytes) {
            if ($b -ge 32 -and $b -le 126) {
                $null = $currentString.Append([char]$b)
            } else {
                if ($currentString.Length -ge 4) {
                    $result.Add($currentString.ToString())
                }
                $currentString.Clear()
            }
        }
        if ($currentString.Length -ge 4) {
            $result.Add($currentString.ToString())
        }
        return $result
    } catch {
        return @()
    }
}

$stringsPath = "$PackageName\strings"
New-Item -ItemType Directory -Force -Path $stringsPath | Out-Null

Write-Host "[+] Converting to readable strings and storing it in $stringsPath folder" -ForegroundColor Yellow
$files = Get-ChildItem -Path $extractPath -File -Recurse
foreach ($file in $files) {
    $relPath = $file.FullName.Substring((Resolve-Path $extractPath).Path.Length + 1)
    $destFile = Join-Path $stringsPath "$relPath.txt"
    $destDir = Split-Path $destFile -Parent
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    
    $stringsData = Get-Strings -Path $file.FullName
    if ($stringsData.Count -gt 0) {
        [System.IO.File]::WriteAllLines($destFile, $stringsData)
    }
}

$grepResultsPath = "$PackageName\GREP-results"
New-Item -ItemType Directory -Force -Path $grepResultsPath | Out-Null

Write-Host "[+] Searching for Base64 values (e.g., JWTs)" -ForegroundColor Yellow
$base64Regex = "eyJ[A-Za-z0-9+/=]*"
$base64File = "$PackageName\base64.txt"
$base64Matches = Get-ChildItem -Path $stringsPath -File -Recurse | Select-String -Pattern $base64Regex -AllMatches | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Value -Unique
if ($base64Matches) {
    [System.IO.File]::WriteAllLines($base64File, $base64Matches)
}

$grepwordsFile = "grepwords.txt"
if (Test-Path $grepwordsFile) {
    Write-Host "[+] Searching for keywords from $grepwordsFile" -ForegroundColor Yellow
    $keywords = Get-Content $grepwordsFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith("#") }
    foreach ($keyword in $keywords) {
        Write-Host "Searching for keyword: " -NoNewline
        Write-Host "$keyword" -ForegroundColor Yellow
        $foundItems = Get-ChildItem -Path $stringsPath -File -Recurse | Select-String -Pattern $keyword
        if ($foundItems) {
            $foundItems | Select-Object -ExpandProperty Line | Set-Content -Path "$grepResultsPath\$keyword.txt"
        }
    }
} else {
    Write-Host "[-] $grepwordsFile not found in current directory. Skipping keyword search." -ForegroundColor Red
}

Write-Host "[+] Done! Results will be available in $PackageName" -ForegroundColor Green
