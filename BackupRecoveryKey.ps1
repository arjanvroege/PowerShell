######################################################################################################################################
###
### Name:           : BackupBitlockRecoveryKey.ps1
### Created by      : David Omisi (Call 2) and Arjan Vroege (KPN Consulting)
### Created on      : 11/21/2017
### Latest Version  : 0.4
### Version History : 0.4 Change Output of script using Out-File
###                   0.3 Added Run as Scheduled Task
###                   0.2 Script improvements 
###                   0.1 First version of the script 
###
######################################################################################################################################

$ArgumentPrep = {
    $Computername            = $env:COMPUTERNAME
    $datetime                = (Get-Date).ToUniversalTime()
    $RPCreated               = 0

    if (Test-Path 'HKCU:\Software\EMS\BitlockerPowerShellFix') {
        Write-Output 'Registry Path Exists'
    } else {
        Write-Output 'Registry Path does not exist, Creating...'
        New-Item 'HKCU:\Software\EMS\BitlockerPowerShellFix' -Force | Out-Null
    }

    do { 

        Clear-Variable -Name BitlockerVolumes,BitlockerVolumesCheck -ErrorAction:SilentlyContinue
        $BitlockerVolumes = Get-BitLockerVolume | where {$_.ProtectionStatus -eq "On"} | where {($_.KeyProtector).KeyProtectorType -notcontains 'RecoveryPassword'}
    
        #$firstrun = $BitlockerVolumes 
        if ($BitlockerVolumes -eq $null) {
            New-ItemProperty -Path 'HKCU:\Software\EMS\BitlockerPowerShellFix' -Name LastScriptRunTimeUTC -Value $datetime -Force | Out-Null
            New-ItemProperty -Path 'HKCU:\Software\EMS\BitlockerPowerShellFix' -Name RecoveryPasswordPresent -Value 1 -Force | Out-Null
            New-ItemProperty -Path 'HKCU:\Software\EMS\BitlockerPowerShellFix' -Name NoActionTakenAtLastRun -Value 1 -Force | Out-Null
        } else {
            foreach ($Volume in $BitlockerVolumes) {
                $BitlockerVolMount = $volume.Mountpoint
            
                if(Add-BitLockerKeyProtector -MountPoint $BitlockerVolMount -RecoveryPasswordProtector) {
                    $RPCreated = 1
                }
            }
               
            #Laatste check / vergelijking maken voor definitieve afronding of hij gaat de loop weer in
            $BitlockerVolumesCheck = Get-BitLockerVolume | where ({$_.ProtectionStatus -eq "On"}) | where ({($_.KeyProtector).KeyProtectorType -notcontains 'RecoveryPassword'})
            if ($BitlockerVolumesCheck -eq $null) {
                New-ItemProperty -Path 'HKCU:\Software\EMS\BitlockerPowerShellFix' -Name LastScriptRunTimeUTC -Value $datetime -Force | Out-Null
                New-ItemProperty -Path 'HKCU:\Software\EMS\BitlockerPowerShellFix' -Name RecoveryPasswordPresent -Value 1 -Force | Out-Null

                $BitlockerVolumes=$null
            }

            if ($RPCreated -eq 1) {
                New-ItemProperty -Path 'HKCU:\Software\EMS\BitlockerPowerShellFix' -Name RecoveryPasswordCreated -Value 1 -Force | Out-Null
                New-ItemProperty -Path 'HKCU:\Software\EMS\BitlockerPowerShellFix' -Name NoActionTakenAtLastRun -Value 0 -Force | Out-Null
            } else {
                New-ItemProperty -Path 'HKCU:\Software\EMS\BitlockerPowerShellFix' -Name RecoveryPasswordCreated -Value 0 -Force | Out-Null
                New-ItemProperty -Path 'HKCU:\Software\EMS\BitlockerPowerShellFix' -Name NoActionTakenAtLastRun -Value 0 -Force | Out-Null
            }
        }         
    } until ($BitlockerVolumes -eq $null)
}

Remove-Item -Path $env:TEMP\BitlockerScript.ps1 -ErrorAction:SilentlyContinue
$ArgumentPrep | Out-File -FilePath $env:TEMP\BitlockerScript.ps1 -Encoding ascii -Force -Width 200

if(!(Get-ScheduledTask -TaskName "Bitlocker Recovery Key" -ErrorAction SilentlyContinue)) {
    schtasks /create /tn "Bitlocker Recovery Key" /sc ONLOGON /ru Users /rl HIGHEST /DELAY 0001:00 /tr "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden -File $env:TEMP\BitlockerScript.ps1"
}





