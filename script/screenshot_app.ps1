$ErrorActionPreference = 'Stop'

# Build flutter web
Write-Host "Building web version..."
Start-Process -FilePath "flutter" -ArgumentList "build", "web", "--no-web-resources-cdn" -WorkingDirectory "C:\AI_Studio\app" -NoNewWindow -Wait

# Start python web server
Write-Host "Starting python server..."
$job = Start-Process -FilePath "python" -ArgumentList "-m", "http.server", "8080", "--directory", "C:\AI_Studio\app\build\web" -PassThru -NoNewWindow

# Wait for server to boot up
Start-Sleep -Seconds 5

# Capture screenshot with headless chrome
Write-Host "Capturing headless screenshot..."
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$screenshotPath = "C:\Users\nabil\.gemini\antigravity\brain\5dba762a-1710-45d5-9443-85c19c23c25e\studio_screenshot.png"

# Use headless=new and remove disable-gpu so WebGL (CanvasKit) works
$chromeProcess = Start-Process -FilePath $chromePath -ArgumentList "--headless=new", "--screenshot=$screenshotPath", "--window-size=1280,720", "--virtual-time-budget=15000", "http://localhost:8080" -PassThru
$chromeProcess.WaitForExit(20000)

Write-Host "Screenshot process complete."

# Cleanup
Write-Host "Cleaning up..."
Stop-Process -Id $job.Id -Force -ErrorAction SilentlyContinue
if (!$chromeProcess.HasExited) {
    Stop-Process -Id $chromeProcess.Id -Force -ErrorAction SilentlyContinue
}

Write-Host "Done!"
