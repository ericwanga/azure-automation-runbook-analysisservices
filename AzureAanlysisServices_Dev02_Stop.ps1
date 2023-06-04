# param(  
#     [parameter(Mandatory=$False, Position=1)]
#     [ValidateLength(1,100)]
#     [string]$AnalysisServer
# )
$RGName = "datagateway01"
$ASName = "devanalysisservices02"

[string] $FailureMessage = "Failed to execute the command"
[int] $RetryCount = 3
[int] $TimeoutInSecs = 20
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
            $devas02 = Get-AzAnalysisServicesServer `
                            -ResourceGroupName $RGName `
                            -Name $ASName  
            Write-Output "$ASName current state: $($devas02.state)"

            if ($devas02.state -eq "Succeeded")
            {
                Write-Output "$ASName state is Succeeded, suspending it"
                Suspend-AzAnalysisServicesServer `
                    -ResourceGroupName $RGName `
                    -Name $ASName
                Write-Output "$ASName is suspended"
            }
            elseif ($devas02.state -eq "Failed")
            {
                Write-Output "$ASName state is Failed, no action was taken. Will attempt restarting it at next scheduled Start time"
            }
            else{
                Write-Output "$ASName is already stopped, no action was taken."
            }

            # new state after the logic
            $devas02_post = Get-AzAnalysisServicesServer `
                                    -ResourceGroupName $RGName `
                                    -Name $ASName
            Write-Output ""
            Write-Output "$ASName current state: $($devas02_post.state)"             
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
