# Script used to prepare node for removal from Puppet management
# Author: Brian Snyder

$hostname = hostname
$logPath = <PATH_TO_LOG_FILE>

# Returns current date/time for logging
# Format = YYYY-MM-DDThh:mm:ss (ISO 8601)
function Get-CurrentTimestamp {
  $timestamp = Get-Date -UFormat "%Y-%m-%dT%T"
  return $timestamp
}

# Logs success to _logPath
function Log-Success {
  Write-Output "$(Get-CurrentTimestamp) - ${hostname} - Puppet service stopped" | Out-File -FilePath $logPath -Encoding "UTF8" -Append
}

# Logs failure to _logPath
function Log-Failure {
  Write-Output "$(Get-CurrentTimestamp) - ${hostname} - Error stopping Puppet service" | Out-File -FilePath $logPath -Encoding "UTF8" -Append
}

# Stop Puppet service and set to disabled
if ((Get-Service puppet).Name -eq 'puppet') {
  Stop-Service puppet
  Set-Service puppet -StartupType disabled
  Sleep 5

  if ((Get-Service puppet).Status -eq 'Stopped') {
    Log-Success
  } else {
    Log-Failure
  }
} else {
  # Puppet not installed.  Nothing to do.
}
