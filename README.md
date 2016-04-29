# Puppet agent scripts  
* Scripts used for install, config, classification, and decomm prep.  

### Description    
Script can be used as-is or as part of a orchestration process for further automation.  
Script takes one parameter that defines the server's role.  This is used to create custom fact
which is used for node classification.  

### Usage:  
Windows: `> Install-PuppetAgent.ps1 -Role base`  
