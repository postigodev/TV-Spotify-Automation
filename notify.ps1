param(
  [Parameter(Mandatory=$true)][string]$Title,
  [Parameter(Mandatory=$true)][string]$Message
)

try {
  Import-Module BurntToast -ErrorAction Stop

  New-BurntToastNotification `
    -Text $Title, $Message `
    -AppLogo (Join-Path $PSScriptRoot "icon.png") `
    -Silent:$false

} catch {
  # Fallback duro si BurntToast no está
  try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, 'OK', 'Information') | Out-Null
  } catch {
    Write-Host "[$Title] $Message"
  }
}
