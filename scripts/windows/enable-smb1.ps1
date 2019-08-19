Write-Output "Enabling SMB1 Protocol..."
# Enable SMB1
Enable-WindowsOptionalFeature -Online -FeatureName smb1protocol -NoRestart
$Key = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
$Setting = 'SMB1'
Set-ItemProperty -Path $Key -Name $Setting -Type DWORD -Value 1 -Force
Write-Output "done."
