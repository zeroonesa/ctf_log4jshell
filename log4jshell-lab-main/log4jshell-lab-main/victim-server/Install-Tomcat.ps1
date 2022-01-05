# Author: Roberto Rodriguez (@Cyb3rWard0g)
# License: MIT

# References:
# https://www.how2shout.com/how-to/install-apache-tomcat-on-windows-10-using-command-prompt.html

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Installing Chocolatey
write-host "Installing Chocolatey.."
if (!(Test-Path "$($env:ProgramData)\chocolatey\choco.exe"))
{
    Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    choco feature enable -n allowGlobalConfirmation
}

# Install OpenJDK 8
# Java installed by tomcat package
#choco install ojdkbuild8 --version=8.0.292
#refreshenv 

# Install Tomcat 9
write-Host "  [*] Installing Tomcat.."
choco install tomcat --version=9.0.19
refreshenv 

# Starting Tomcat service
& sc.exe config tomcat9 start= auto

Restart-Service -Name tomcat9 -Force

write-Host "  [*] Verifying if tomcat is running.."
$s = Get-Service -Name tomcat9
while ($s.Status -ne 'Running') { Start-Service tomcat9; Start-Sleep 3 }
Start-Sleep 5
write-Host "  [*] tomcat9 is running.."

# Install Git
write-Host "  [*] Installing Git.."
choco install git.install --params "/GitAndUnixToolsOnPath /NoGitLfs /SChannel /NoAutoCrlf"
refreshenv

# Install Maven
write-Host "  [*] Installing Maven.."
choco install maven --version=3.8.4
refreshenv
