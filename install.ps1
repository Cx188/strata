[CmdletBinding()]
param(
  [string]$InstallDir
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
  throw 'This installer command is for Windows. Use the macOS or Linux package from the Strata GitHub Releases page.'
}

if (-not $env:LOCALAPPDATA) {
  throw 'Windows did not provide a LOCALAPPDATA folder for this user.'
}

$defaultInstallDir = Join-Path $env:LOCALAPPDATA 'Programs\Strata'
if (-not $InstallDir) {
  $chosenInstallDir = Read-Host "Install Strata to [$defaultInstallDir]"
  $InstallDir = if ([string]::IsNullOrWhiteSpace($chosenInstallDir)) {
    $defaultInstallDir
  } else {
    $chosenInstallDir.Trim().Trim('"')
  }
}

$InstallDir = [Environment]::ExpandEnvironmentVariables($InstallDir)
$InstallDir = [IO.Path]::GetFullPath($InstallDir)
$releaseApi = 'https://api.github.com/repos/Cx188/strata/releases/latest'
$headers = @{
  Accept = 'application/vnd.github+json'
  'User-Agent' = 'Strata-Windows-Installer'
}
$temporaryInstaller = Join-Path ([IO.Path]::GetTempPath()) "Strata-Setup-$([Guid]::NewGuid().ToString('N')).exe"

Write-Host ''
Write-Host 'Strata installer' -ForegroundColor Green
Write-Host "Destination: $InstallDir"
Write-Host 'Finding the latest stable release...'

try {
  $release = Invoke-RestMethod -Uri $releaseApi -Headers $headers
  $setupAsset = $release.assets |
    Where-Object { $_.name -match '^Strata-Windows-Setup-[0-9].*\.exe$' } |
    Select-Object -First 1

  if (-not $setupAsset) {
    throw 'The latest Strata release does not contain a Windows setup installer.'
  }

  Write-Host "Downloading $($setupAsset.name)..."
  Invoke-WebRequest -Uri $setupAsset.browser_download_url -Headers $headers -OutFile $temporaryInstaller

  $expectedDigest = [string]$setupAsset.digest
  if ($expectedDigest -notmatch '^sha256:(?<hash>[a-fA-F0-9]{64})$') {
    throw 'The latest Strata release is missing a verifiable Windows installer.'
  }
  Write-Host 'Verifying download...'
  $actualDigest = (Get-FileHash -LiteralPath $temporaryInstaller -Algorithm SHA256).Hash
  if ($actualDigest -ne $Matches.hash) {
    throw 'The downloaded installer failed SHA-256 verification. Nothing was installed.'
  }

  Write-Host 'Installing Strata...'
  # NSIS requires /D to be the final argument and treats the remainder as the
  # destination, including spaces.
  $installProcess = Start-Process `
    -FilePath $temporaryInstaller `
    -ArgumentList "/S /D=$InstallDir" `
    -Wait `
    -PassThru

  if ($installProcess.ExitCode -ne 0) {
    throw "The Strata setup program exited with code $($installProcess.ExitCode)."
  }

  $strataExecutable = Join-Path $InstallDir 'Strata.exe'
  if (-not (Test-Path -LiteralPath $strataExecutable -PathType Leaf)) {
    throw "Installation finished, but Strata.exe was not found in $InstallDir."
  }

  Write-Host 'Creating desktop shortcut...'
  $desktop = [Environment]::GetFolderPath('Desktop')
  $shortcutPath = Join-Path $desktop 'Strata.lnk'
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = $strataExecutable
  $shortcut.WorkingDirectory = $InstallDir
  $shortcut.IconLocation = "$strataExecutable,0"
  $shortcut.Description = 'Launch Strata'
  $shortcut.Save()

  Write-Host 'Launching Strata...' -ForegroundColor Green
  Start-Process -FilePath $strataExecutable -WorkingDirectory $InstallDir
  Write-Host 'Done. Strata is installed and the desktop shortcut is ready.' -ForegroundColor Green
} finally {
  if (Test-Path -LiteralPath $temporaryInstaller) {
    Remove-Item -LiteralPath $temporaryInstaller -Force
  }
}
