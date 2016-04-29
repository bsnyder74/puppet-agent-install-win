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

$_hostname = hostname
$_msiexecPath = "C:\Windows\System32\msiexec.exe"
$_args = '/qn /i'
$_path = <PATH_TO_INSTALL>
$_agent = <INSTALLATION_FILE>
$_pptServer = 'PUPPET_MASTER_SERVER=<PUPPET_MASTER>'
$_env = 'production'
$_pptEnv = "ENVIRONMENT=$_env"
$_logPath = <PATH_TO_INSTALLATION_LOG>
$_logClassPath = <PATH_TO_CLASSIFICATION_LOG>
$_factsPath = "C:\ProgramData\PuppetLabs\facter\facts.d"
$_puppetPath = "C:\Program Files\Puppet Labs\Puppet\bin"
$_agentArgs = "agent --test --waitforcert 10 --onetime"
$webclient = new-object System.Net.WebClient

## Helper functions ##
# Returns current date/time for logging
# Format = YYYY-MM-DDThh:mm:ss (ISO 8601)
function Get-CurrentTimestamp {
  $_timestamp = Get-Date -UFormat "%Y-%m-%dT%T"
  return $_timestamp
}

# Logs success to _logPath
function Log-Success {
  Write-Output "$(Get-CurrentTimestamp) - ${_hostname} - $_agent Installed" | Out-File -FilePath $_logPath -Encoding "UTF8" -Append
}

# Logs failure to _logPath
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

  Write-Output "$(Get-CurrentTimestamp) - ${_hostname} - $ErrorCode : $Description" | Out-File -FilePath $_logPath -Encoding "UTF8" -Append
}

function Log-Classification {
  Write-Output "$(Get-CurrentTimestamp) - ${_hostname} - $_agent classified with role $Role" | Out-File -FilePath $_logClassPath -Encoding "UTF8" -Append
}

## END Helper functions ##

function Install-PuppetAgent {
  Try {
    Start-Process -FilePath $_msiexecPath -ArgumentList "$_args $_path\$_agent $_pptServer $_pptEnv" -Wait -ErrorAction Stop

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

# TODO: Change below to create custom fact based on passed in param instead of matching case statement (future)
function Create-CustomFacts {
  Switch ($Role) {
    "web" {
      @{"custom.role"="iis"} | ConvertTo-Json | Out-File -Encoding "OEM" -FilePath $_factsPath\facts.json
    }
    "database" {
      @{"custom.role"="mssql"} | ConvertTo-Json | Out-File -Encoding "OEM" -FilePath $_factsPath\facts.json
    }
    "application" {
      @{"custom.role"="base"} | ConvertTo-Json | Out-File -Encoding "OEM" -FilePath $_factsPath\facts.json
    }
    Default {
      @{"custom.role"="base"} | ConvertTo-Json | Out-File -Encoding "OEM" -FilePath $_factsPath\facts.json
    }
  }
}

function Request-CertSign {
  if (Test-Path $_factsPath\facts.json) {
    Start-Process -FilePath $_puppetPath\puppet -ArgumentList "$_agentArgs" -Wait -ErrorAction Stop
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
