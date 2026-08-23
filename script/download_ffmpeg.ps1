$ErrorActionPreference = 'Stop'
$url = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
$zipPath = "C:\AI_Studio\ffmpeg.zip"
$extractPath = "C:\AI_Studio\ffmpeg_extract"
$destPath = "C:\AI_Studio\bin"

Write-Host "Downloading FFmpeg..."
Invoke-WebRequest -Uri $url -OutFile $zipPath

Write-Host "Extracting..."
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

Write-Host "Moving binary..."
if (!(Test-Path $destPath)) {
    New-Item -ItemType Directory -Force -Path $destPath
}
$ffmpegExe = Get-ChildItem -Path $extractPath -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
Move-Item -Path $ffmpegExe.FullName -Destination "$destPath\ffmpeg.exe" -Force

Write-Host "Cleaning up..."
Remove-Item -Path $zipPath -Force
Remove-Item -Path $extractPath -Recurse -Force

Write-Host "FFmpeg installed to $destPath\ffmpeg.exe"
