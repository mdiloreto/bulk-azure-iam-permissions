param ( 
    # Map each SubscriptionId to a list of ResourceGroupNames
    [Parameter(Mandatory)]
    [hashtable]$SubscriptionToResourceGroups,

    # List of role names to be assigned at subscription level
    [Parameter(Mandatory)]
    [string[]]$SubscriptionRoles,

    # List of role names to be assigned at resource group level
    [Parameter(Mandatory)]
    [string[]]$ResourceGroupRoles,

    [Parameter(Mandatory)]
    [string]$SPNObjectId
)

foreach ($subscriptionId in $SubscriptionToResourceGroups.Keys) {
    
    Write-Host "Processing Subscription: $subscriptionId" -ForegroundColor Cyan
    
    # 0) Select subscription
    try {
        Select-AzSubscription -SubscriptionId $subscriptionId -ErrorAction Stop
        Write-Host "Successfully selected subscription: $subscriptionId"
    }
    catch {
        Write-Host "Failed to select subscription $subscriptionId :" -ForegroundColor Red
        Write-Host $_.Exception.Message
        continue 
    }

    # 1) Assign Subscription-Level Roles
    
    Write-Host "  Assigning subscription-level roles..." -ForegroundColor Cyan
    foreach ($role in $SubscriptionRoles) {
        try {
            Write-Host "   -> Assigning role '$role' at subscription scope."
            New-AzRoleAssignment -ObjectId $SPNObjectId -RoleDefinitionName $role -Scope "/subscriptions/$subscriptionId" -ErrorAction Stop
            Write-Host "      [OK] Role '$role' assigned."
        }
        catch {
            Write-Host "Failed to assign role '$role' at subscription scope." -ForegroundColor Red
            Write-Host $_.Exception.Message
            # Decide if you want to 'continue' or 'throw'
            continue
        }
    }

    # 2) Assign Resource Group-Level Roles
    
    $rgList = $SubscriptionToResourceGroups[$subscriptionId]
    if ($rgList -and $rgList.Count -gt 0) {
        Write-Host "  Assigning resource-group-level roles..." -ForegroundColor Cyan
        
        foreach ($rgName in $rgList) {
            Write-Host "   -> Resource Group: $rgName"
            
            foreach ($rgRole in $ResourceGroupRoles) {
                try {
                    Write-Host "      -> Assigning role '$rgRole' at RG scope."
                    New-AzRoleAssignment -ObjectId $SPNObjectId -RoleDefinitionName $rgRole -Scope "/subscriptions/$subscriptionId/resourceGroups/$rgName" -ErrorAction Stop                    
                    Write-Host "         [OK] Role '$rgRole' assigned."
                }
                catch {
                    Write-Host "Failed to assign role '$rgRole' at resource group: $rgName" -ForegroundColor Red
                    Write-Host $_.Exception.Message
                    # Decide if you want to continue or throw
                    continue
                }
            }
        }
    }
    else {
        Write-Host "  No resource groups listed for subscription $subscriptionId."
    }

    Write-Host ""
} 

Write-Host "`nAll role assignments completed (or attempted) successfully."
