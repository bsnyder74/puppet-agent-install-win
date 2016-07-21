# Puppet agent scripts  
* Scripts used for install, config, classification, and decomm prep.  

### Description:      
Script can be used as-is or as part of a orchestration process for further automation.  
Script takes one parameter that defines the server's role.  This is used to create trusted facts
which ae used for node classification.  

### Requirements:  
[puppet-pe_install_ps1](https://github.com/natemccurdy/puppet-pe_install_ps1) installed on Puppet master.  
PowerShell 2.0 + on nodes that the script will be ran on.  
Execution mode needs to be 'unrestricted'.  

### Usage:  
Windows: `> Install-PuppetAgent.ps1 -Role base -SevEnv production`  
