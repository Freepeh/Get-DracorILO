<#
.SYNOPSIS
 Outputs DRAC and ILO IP information for vmhosts listed in a text file. 
.DESCRIPTION
 Given list of fully qualified host names in a text file, plus credentials variable, this will 
 attempt to login with the credentials and output the DRAC and/or ILO IP for each.  In addition,
 the default log file of get-dracorilo.log will contain failures if the root password did not 
 succeed effectively using this as a password validator as a second 'feature'.

 If this cmdlet isnt working, do the following:
 open gpedit.msc and modify:
 localcomputer policy > Computer config / Admin templates / WIndows Components/WIndows Remote Management
 (WinRM) / WinRM CLient

 Ensure "allow Basic Authentication" and "allow unencrytped traffic" are set to 'Not Configure'
 THen run a gpupdate / force 

 You can also then do this in your powershell session:
winrm set winrm/config/client/auth '@{Basic="true"}'winrm set winrm/config/client '@{AllowUnencrypted="true"}'

.PARAMETER  <Parameter-Name>
.INPUTS
.OUTPUTS
.EXAMPLE
 get-vmhost lrb* | select -ExpandProperty name | Out-File lrb.txt
 Get-DRACorILO -hosttxtfile .\lrb.txt -Credential $cred

VMhost                                                                   DRAC/ILO IP                                                            
------                                                                   -----------                                                            
lrb-vs01buf.lrb.ds.usace.army.mil                                        10.17.21.1                                                             
lrb-vs02buf.lrb.ds.usace.army.mil                                        10.17.21.2                                                             
lrb-vs03buf.lrb.ds.usace.army.mil                                        10.17.21.3   
#>
    [cmdletbinding()]    
    param([parameter(mandatory=$true)]
            [string]$hosttxtfile,
          [parameter(mandatory=$false)]
            [string]$LogFile = 'Get-DRACorILO.log',
            [PSCredential]$Credential = (Get-Credential -Message "Enter Password for ESX(i) Hosts" -UserName root),
            [switch]$Passwordcheckonly

    )
    BEGIN {
        #Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client' -Name 'AllowBasic' -Value '1' -Confirm:$FALSE
        $date = get-date -Format "MMddyyyy:hhmm"
        import-module CimCmdlets
        #$creds = Get-Credential -Message "Enter Password for ESX(i) Hosts" -UserName root
        $CIOpt = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -Encoding Utf8 -UseSsl
        $ErrorActionPreference = 'SilentlyContinue'
    }
    PROCESS {
        #if (test-path $LogFile) { Remove-Item -Path $LogFile -Confirm:$false  }
        foreach ($vmhost in Get-Content $hosttxtfile) {
            try{
                $props = @{'Authentication'= "Basic";
                           'Credential'=$Credential;
                           'ComputerName'=$vmhost;
                           'port' = 443;
                           'SessionOption'=$CIOpt;
                           'ErrorAction'= "Stop"
                          }
                $Session = New-CimSession @props

                if ( $Passwordcheckonly) {
                    write-host "Successful password login to $vmhost" -ForegroundColor Cyan
                    Write-Output "$date : Success on $vmhost" | Out-File $LogFile -Append 
                    Remove-CimSession $Session
                    } else {
                        $bmc = Get-CimInstance -CimSession $Session -ClassName CIM_IPProtocolEndpoint -ErrorAction SilentlyContinue
                        $bmc.GetEnumerator() | ? caption -eq 'Management Controller IP Interface' | select @{n='VMhost';e={$_.pscomputername}},@{n='DRAC/ILO IP';e={$_.ipv4address}}
                        Remove-CimSession $Session
                    }

            } catch {
                write-host "Failed password login to $vmhost" -foregroundcolor Red
                Write-Output "$date : Password failed on $vmhost" | Out-File $LogFile -Append
              }
        }#foreach
    }#process
    END { 
        $ErrorActionPreference = 'Continue'
        #Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client' -Name 'AllowBasic' -Value '0' -Confirm:$FALSE
    }
