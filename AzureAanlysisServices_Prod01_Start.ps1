# param(  
#     [parameter(Mandatory=$True, Position=0)]
#     [ValidateLength(1,100)]
#     [string]$ASName
# )

$RGName = "prodanalysisservices01_RG"
$ASName = "prodanalysisservices01"

[string] $FailureMessage = "Failed to execute the command"
[int] $RetryCount = 3
[int] $TimeoutInSecs = 10
$RetryFlag = $true
$Attempt = 1

# "Logging in to Azure ..."
$connectionName = "AzureRunAsConnection"
while($RetryFlag)
{
    try
        {
            # Get the connection "AzureRunAsConnection "
            $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

            Add-AzAccount `
                -ServicePrincipal `
                -TenantId $servicePrincipalConnection.TenantId `
                -ApplicationId $servicePrincipalConnection.ApplicationId `
                -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
            
            Write-Output "Successfully logged into Azure subscription using Az cmdlets..."

            # $azsub=GET-AzSubscription
            # Write-Output "Subscription name:" $azsub.Name "Subscription state:" $azsub.State

            # check current state
            $prodas01 = Get-AzAnalysisServicesServer `
                            -ResourceGroupName $RGName `
                            -Name $ASName
                            
            Write-Output "$ASName current state: $($prodas01.state)"

            # actions to start
            if ($prodas01.state -eq "Paused" -or $prodas01.state -eq "Suspended")
            {
                Write-Output "$ASName is Paused, resuming it"
                Resume-AzAnalysisServicesServer `
                    -ResourceGroupName $RGName `
                    -Name $ASName
                Write-Output "$ASName is resumed"
            }
            elseif ($prodas01.state -eq "Failed")
            {
                Write-Output "$ASName state is Failed, restarting it"
                Restart-AzAnalysisServicesServer `
                    -ResourceGroupName $RGName `
                    -Name $ASName
                Write-Output "$ASName is restarted"
            }
            else{
                Write-Output "$ASName is already running, no actions were taken."
            }

            # check server state again
            $prodas01_post = Get-AzAnalysisServicesServer `
                            -ResourceGroupName $RGName `
                            -Name $ASName
            Write-Output ""
            Write-Output "$ASName current state: $($prodas01_post.state)"
            Write-Output "Complete"
            
            $RetryFlag = $false
        }
        catch 
        {
            if (!$servicePrincipalConnection)
            {
                $ErrorMessage = "Connection $connectionName not found."
                $RetryFlag = $false
                throw $ErrorMessage
            }

            if ($Attempt -gt $RetryCount) 
            {
                Write-Output "$FailureMessage! Total retry attempts: $RetryCount"
                Write-Output "[Error Message] $($_.exception.message) `n"
                $RetryFlag = $false
            }
            else 
            {
                $ex = $_.Exception
                Write-Output $_.Exception
                Write-Output "[$Attempt/$RetryCount] $FailureMessage. Retrying in $TimeoutInSecs seconds..."
                Start-Sleep -Seconds $TimeoutInSecs
                $Attempt = $Attempt + 1
            }   
        }
}
