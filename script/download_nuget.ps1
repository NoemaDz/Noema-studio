$ErrorActionPreference = 'Stop'
$url = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$destPath = "C:\AI_Studio\bin\nuget.exe"

Write-Host "Downloading nuget.exe..."
Invoke-WebRequest -Uri $url -OutFile $destPath
Write-Host "nuget.exe downloaded to $destPath"
