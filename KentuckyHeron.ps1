# Windows Setup and Configuration Script
#
# This script automates the installation of common applications and configures
# pGina for authentication against a FreeIPA LDAP server.
Write-Host "Checking for Administrator privileges..."
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script must be run as Administrator. Please re-run from an elevated PowerShell terminal."
    Read-Host "Press Enter to exit..."
    exit
}

Write-Host "Checking for Chocolatey package manager..."
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey not found. Installing..."
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
} else {
    Write-Host "Chocolatey is already installed."
}

Write-Host "Installing requested applications. This may take a considerable amount of time."

$packages = @(
    "steam",
    "googlechrome",
    "firefox",
    "sublimetext4",
    "onlyoffice",
    "discord",
    "powershell-core", # Installs PowerShell 7
    "heroicgameslauncher",
    "battle.net",
    "audacity",
    "shotcut",
    "signal",
    "wireshark",
    "nvidia-display-driver", # Installs latest NVIDIA driver. For specific versions (Game Ready vs Studio), manual install might be better.
    "pgina"
)

foreach ($pkg in $packages) {
    Write-Host "Installing $pkg..."
    choco install $pkg -y --force
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install $pkg. Please check the output above."
    }
}

Write-Host "Application installation complete."

Write-Host "Configuring pGina to connect to ldap.loganbrown.cc..."

$pginaBaseReg = "HKLM:\SOFTWARE\pGina3"

$ldapPluginReg = "$pginaBaseReg\Plugins\{B4E383A6-2239-4448-A583-3475AC242340}"

if (-not (Test-Path $pginaBaseReg)) {
    Write-Error "pGina registry key not found. Configuration cannot proceed. Was pGina installed correctly?"
    Read-Host "Press Enter to exit..."
    exit
}

Set-ItemProperty -Path $pginaBaseReg -Name "PluginOrder_Authentication" -Value @("{B4E383A6-2239-4448-A583-3475AC242340}") -Type MultiString
Set-ItemProperty -Path $pginaBaseReg -Name "PluginOrder_Authorization" -Value @("{B4E383A6-2239-4448-A583-3475AC242340}") -Type MultiString
Set-ItemProperty -Path $pginaBaseReg -Name "PluginOrder_Gateway" -Value @("{B4E383A6-2239-4448-A583-3475AC242340}") -Type MultiString

if (-not (Test-Path $ldapPluginReg)) {
    New-Item -Path $ldapPluginReg -Force
}

Write-Host "Setting LDAP connection details..."
Set-ItemProperty -Path $ldapPluginReg -Name "LdapHost" -Value "ldap.loganbrown.cc"
Set-ItemProperty -Path $ldapPluginReg -Name "LdapPort" -Value 389
Set-ItemProperty -Path $ldapPluginReg -Name "UseSsl" -Value 0 -Type DWord # Set to 1 for LDAPS on port 636, requires client-side certificate setup
Set-ItemProperty -Path $ldapPluginReg -Name "SearchDN" -Value "ou=People,dc=ldap,dc=loganbrown,dc=cc"
Set-ItemProperty -Path $ldapPluginReg -Name "SearchFilter" -Value "(uid=%u)"
Set-ItemProperty -Path $ldapPluginReg -Name "GroupDNPattern" -Value "cn=%g,ou=Groups,dc=ldap,dc=loganbrown,dc=cc"
Set-ItemProperty -Path $ldapPluginReg -Name "GroupMemberAttrib" -Value "member" # For posixGroup, this is often memberUid
Set-ItemProperty -Path $ldapPluginReg -Name "GroupAuthz" -Value 1 -Type DWord # Authorize based on group membership
Set-ItemProperty -Path $ldapPluginReg -Name "RequiredGroups" -Value "networkusers" -Type MultiString # Only allow members of the 'networkusers' IPA group to log in

Write-Host "pGina configuration complete."
Write-Host "------------------------------------------------------------"
Write-Host "FINAL SETUP COMPLETE. A RESTART IS RECOMMENDED."
Write-Host "After restarting, you should be able to log in with your FreeIPA user credentials at the Windows login screen."
