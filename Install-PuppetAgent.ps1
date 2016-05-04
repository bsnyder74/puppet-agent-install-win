################################################################
# Installs Puppet Agent for Windows (64-bit)
# Creates custom fact based on custom role
# Performs initial puppet run for cert request and initial state
# Cert signing handled via orchestration outside this scripts
# Basic logging to a shared location
# Error codes are custom NOT related to puppet install
#
# Author: Brian Snyder
################################################################

# Parameters
param (
  [Parameter(
    HelpMessage="What is this parameter?",
    Position=0,
    Mandatory=$true
  )]
    [String]$Role
)

$hostname = hostname
$msiexecPath = "C:\Windows\System32\msiexec.exe"
$args = '/qn /i'
$path = <PATH_TO_INSTALL>
$agent = <INSTALLATION_FILE>
$pptServer = 'PUPPET_MASTER_SERVER=<PUPPET_MASTER>'
$env = 'production'
$pptEnv = "ENVIRONMENT=$env"
$logPath = <PATH_TO_INSTALLATION_LOG>
$logClassPath = <PATH_TO_CLASSIFICATION_LOG>
$factsPath = "C:\ProgramData\PuppetLabs\facter\facts.d"
$puppetPath = "C:\Program Files\Puppet Labs\Puppet\bin"
$agentArgs = "agent --test --waitforcert 10"
$webclient = new-object System.Net.WebClient

## Helper functions ##
# Returns current date/time for logging
# Format = YYYY-MM-DDThh:mm:ss (ISO 8601)
function Get-CurrentTimestamp {
  $timestamp = Get-Date -UFormat "%Y-%m-%dT%T"
  return $timestamp
}

# Logs success to _logPath
function Log-Success {
  Write-Output "$(Get-CurrentTimestamp) - ${hostname} - $agent Installed" | Out-File -FilePath $logPath -Encoding "UTF8" -Append
}

# Logs failure to logPath
function Log-Failure {
  param (
    [Parameter(
      HelpMessage="What is this parameter?",
      Position=0,
      Mandatory=$true
      )]
      [String]$ErrorCode,
    [Parameter(
      HelpMessage="What is this parameter?",
      Position=1,
      Mandatory=$true
      )]
      [String]$Description
  )

  Write-Output "$(Get-CurrentTimestamp) - ${hostname} - $ErrorCode : $Description" | Out-File -FilePath $logPath -Encoding "UTF8" -Append
}

function Log-Classification {
  Write-Output "$(Get-CurrentTimestamp) - ${hostname} - $agent classified with role $Role" | Out-File -FilePath $logClassPath -Encoding "UTF8" -Append
}

## END Helper functions ##

function Install-PuppetAgent {
  Try {
    Start-Process -FilePath $msiexecPath -ArgumentList "$args $path\$agent $pptServer $pptEnv" -Wait -ErrorAction Stop

    if (Get-Service puppet) {
      Log-Success
    } else {
      Log-Failure -ErrorCode 'Error 13' -Description 'Puppet service not found.'
      Exit 13
    }

  }
  Catch {
    Log-Failure -ErrorCode 'Error 12' -Description 'Puppet agent install FAILED.'
    Exit 12
  }
}

# TODO: Change below to create custom fact based on passed in param instead of matching case statement
function Create-CustomFacts {
  Switch ($Role) {
    "web" {
      @{"custom.role"="iis"} | ConvertTo-Json | Out-File -Encoding "OEM" -FilePath $factsPath\facts.json
    }
    "database" {
      @{"custom.role"="mssql"} | ConvertTo-Json | Out-File -Encoding "OEM" -FilePath $factsPath\facts.json
    }
    "application" {
      @{"custom.role"="base"} | ConvertTo-Json | Out-File -Encoding "OEM" -FilePath $factsPath\facts.json
    }
    Default {
      @{"custom.role"="base"} | ConvertTo-Json | Out-File -Encoding "OEM" -FilePath $factsPath\facts.json
    }
  }
}

function Request-CertSign {
  if (Test-Path $factsPath\facts.json) {
    Start-Process -FilePath $puppetPath\puppet -ArgumentList "$agentArgs" -Wait -ErrorAction Stop
  } else {
    Log-Failure -ErrorCode 'Error 14' -Description 'Custom fact not found.  Unable to classify node.'
    Exit 14
  }
}

Install-PuppetAgent
Create-CustomFacts
Sleep 30 # workaround for race condition described in PUP-2958
Request-CertSign
Log-Classification
