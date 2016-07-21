################################################################
# Installs Puppet Agent for Windows (64-bit)
# Creates custom fact based on custom role
# Performs initial puppet run for cert request and initial state
# Cert signing handled via orchestration outside this scripts
# Basic logging to a shared location
# Error codes are custom NOT related to puppet install
################################################################

# Parameters
param (
  [Parameter(
    Position=0,
    Mandatory=$true
  )]
    [String]$Role,
  [Parameter(
    Position=1,
    Mandatory=$true,
  )]
    [String]$SecEnv
)

$hostname = hostname
$url = "https://<puppet_server>:8140/packages/current/install.ps1"
$pptConfDir = "C:\ProgramData\PuppetLabs\puppet\etc"
$logPath = <PATH_TO_INSTALLATION_LOG>
$logClassPath = <PATH_TO_CLASSIFICATION_LOG>
$puppetPath = "C:\Program Files\Puppet Labs\Puppet\bin"

## Helper functions ##
# Returns current date/time for logging
# Format = YYYY-MM-DDThh:mm:ss (ISO 8601)
function Get-CurrentTimestamp {
  $timestamp = Get-Date -UFormat "%Y-%m-%dT%T"
  return $timestamp
}

# Logs success to logPath
function Log-Success {
  Write-Output "$(Get-CurrentTimestamp) - ${hostname} - $agent Installed" | Out-File -FilePath $logPath -Encoding "UTF8" -Append
}

# Logs failure to logPath
function Log-Failure {
  param (
    [Parameter(
      Position=0,
      Mandatory=$true
      )]
      [String]$ErrorCode,
    [Parameter(
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

function Create-CustomFacts {

  if !(Test-Path $pptConfDir) {
    mkdir $pptConfDir
  } else {
    Write-Debug "Puppet Conf Dir already exists. Continuing ..."
  }

  Switch ($Role) {
    "web" { $pp_role = 'iis' }
    "database" { $pp_role = 'mssql' }
    "application" { $pp_role = 'base' }
    Default { $pp_role = 'base' }
  }

  Try {
    $yaml = "---
    extension_requests:
      pp_role: $pp_role
      pp_securitypolicy: $SecEnv"

    $yaml | Out-File -Encoding "OEM" -FilePath $pptConfDir\csr_attributes.yaml
  }

  Catch {
    Log-Failure -ErrorCode 'Error 14' -Description 'Creating trusted facts FAILED.'
    Exit 14
  }
}

function Install-PuppetAgent {
  if (Test-Path $pptConfDir\csr_attributes.yaml) {

    Try {
      [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
      $webClient = New-Object System.Net.WebClient
      $webClient.DownloadFile("$url", "$env:temp\install-agent.ps1"); & "$env:temp\install-agent.ps1"
    }

    Catch {
      Log-Failure -ErrorCode 'Error 12' -Description 'Puppet agent install FAILED.'
      Exit 12
    }

  } else {
    Log-Failure -ErrorCode 'Error 14' -Description 'Trusted Facts do not exist.  FAILED.'
    Exit 13
  }
}

Create-CustomFacts
Install-PuppetAgent
Log-Classification
