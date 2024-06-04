$available_drives = (Get-PSDrive -PSProvider 'FileSystem').Root

$listOfPossibleClientAccounts = @(
    '360iQClient'
    , 'Subway'
    #,'dtiquser'# TEMPORARILY DISABLED
)

#------- FUNCTIONS SETUP -------
function Get-ActiveUser {
    # Find all active users that match provided list, useful for finding multiple admin or client accounts
    param (
        <#
            PARAMETERS
            _______
            Users | All account names to look for in enabled accounts list
        #>
        [Parameter(Mandatory, ValueFromPipeline)] [string[]] $Users
    )

    process {
        $foundUsers = @()
        $enabledUserNames = (Get-LocalUser | Where-Object Enabled -eq $True).Name
        foreach ($user in $Users) {
            if ($enabledUserNames.Contains($user)) {
                $foundUsers += $user
            }
        }
        return $foundUsers
    }
}

function Set-AclRule {
    <#
    Builds rule dynamically from parameters and adds/removes it on specified paths, can enable inheritance on whole tree to make sure that rule is inherited
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        <#
            PARAMETERS
            __________________
            Identity         | Username or Identity for rule processing
            Rule             | File/Directory permission that you would like to add or delete
            Value            | Specifies if rule should be Allow or Deny
            InheritanceFlags | Configures inheritance of the permissions, if sub-folders and files have inheritance enabled, Container and Object inherit will move rule across
            PropagationFlags | Controlls if current file/directory should have rule applied. None -> This folder
            Paths            | Array of paths to apply rule to
            Remove           | Flag to control rule deletion, $True -> Remove rule specified by previous parameters
            RecurseInherit   | Flag to control inheritance of subfolder and files, $True -> loop over child paths and enable inheritance
        #>
        [Parameter(Mandatory)] [String] $Identity,
        [Parameter(Mandatory)] [ValidateScript({[System.Security.AccessControl.FileSystemRights].GetEnumValues()})] [String] $Rule,
        [Parameter(Mandatory)] [ValidateSet('Allow', 'Deny')] [String] $Value,
        [ValidateSet('None', 'ContainerInherit', 'ObjectInherit')] [String[]] $InheritanceFlags = 'None',
        [ValidateSet('None', 'NoPropagateInherit', 'InheritOnly')] [String[]] $PropagationFlags = 'None',
        [Parameter(Mandatory)] [String[]] $Paths,
        [switch] $Remove = $False,
        [switch] $RecurseInherit = $False
    )

    #Build rule from parameters
    $fileSystemAccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Identity, $Rule, $InheritanceFlags, $PropagationFlags, $Value)

    
    foreach ($path in $Paths) {
        # Enable inheritance from Root path on all child objects
        if ($True -eq $RecurseInherit) {
            try {
                $childPaths = (Get-ChildItem -LiteralPath $path -Recurse).FullName
                foreach ($childPath in $childPaths) {
                    try {
                        $childAcl = Get-Acl -LiteralPath $childPath
                        $childAcl.Access | ForEach-Object {$childAcl.RemoveAccessRule($_)} | Out-Null
                        # Enable Inheritance, remove old rules is ignored in this case
                        $childAcl.SetAccessRuleProtection($false, $false)
                        Set-Acl -LiteralPath $childPath -AclObject $childAcl
                        Write-Output("Inheritance enabled for: $childPath")
                    } catch {
                        Write-Output("Failed enable Inheritance for: $childPath")
                        continue
                    }
                }
            } catch {
                Write-Output($_)
            }
        }
        
        # Set Rule on Root path and disable inheritance from parent preserving inherited rules
        try {
            $acl = Get-Acl -LiteralPath $path
            if ($Remove.IsPresent) {
                $acl.RemoveAccessRule($fileSystemAccessRule) | Out-Null
            }
            else {
                $acl.AddAccessRule($fileSystemAccessRule)
            }
            # Disable inheritance and preserve parent rules
            $acl.SetAccessRuleProtection($true, $true)
            Set-Acl -LiteralPath $path -AclObject $acl
            Write-Output("Access rule modified on root: $path")
        }
        catch {
            Write-Output("Cannot modify access rule on root: $path")
            continue
        }
    }
}

function Remove-AclForUser {
    <#
    Removes Allow/Deny rules for specified identity, can remove rules on whole tree
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        <#
            PARAMETERS
            ________________
            Identities     | Usernames to remove all rules for
            Paths          | Array of paths to remove rules on
            Value          | Control which rule to remove, All/ Only Allow / Only Deny rules for specified identity
            RecurseInherit | Flag to control inheritance of subfolder and files, $True -> loop over child paths and enable inheritance removing specified rule as well
        #>
        [Parameter(Mandatory)] [string[]] $Identities,
        [Parameter(Mandatory)] [string[]] $Paths,
        [ValidateSet('All', 'Allow', 'Deny')] [string] $Value = 'All',
        [switch] $RecurseInherit = $False
    )

    foreach ($path in $Paths) {
        # Enable inheritance from Root path on all child objects
        if ($True -eq $RecurseInherit) {
            try {
                $childPaths = (Get-ChildItem -LiteralPath $path -Recurse).FullName
                foreach ($childPath in $childPaths) {
                    try {
                        $acl = Get-Acl -LiteralPath $childPath
                        $acl.Access | ForEach-Object {$acl.RemoveAccessRule($_)} | Out-Null
                        # Enable Inheritance, removal is ignored in this case
                        $acl.SetAccessRuleProtection($false, $false)
                        Set-Acl -LiteralPath $childPath -AclObject $acl
                        Write-Output("Inheritance enabled for: $childPath")
                    } catch {
                        Write-Output("Failed enable Inheritance for: $childPath")
                        continue
                    }
                }
            } catch {
                Write-Output($_)
            }
        }

        try{
            $acl = Get-Acl -LiteralPath $path
            # Disable inheritance and keep inherited rules as base for edition
            $acl.SetAccessRuleProtection($true, $true)

            foreach ($identity in $Identities) {
                # Gather all rules that match Identity
                $accessRulesForUser = $acl.Access | Where-Object -Property IdentityReference -Match -Value $identity
                if ($Value -ne 'All') {
                    # Filter out rules per Allow/Deny if provided as argument
                    $accessRulesForUser = $accessRulesForUser | Where-Object -Property AccessControlType -Match -Value $Value
                }

                # Remove all rules that match criteria
                $accessRulesForUser | ForEach-Object {$acl.RemoveAccessRule($_)} | Out-Null
            }
            Set-Acl -LiteralPath $path -AclObject $acl
            Write-Output("Access rules removed on root: $path")
        } catch {
            Write-Output("Cannot remove access rules on root: $path")
            continue
        }
    }
}

function Remove-ApplicationPackagesFromAcl {
    <#
    Removes ALL APPLICATION PACKAGES and ALL RESTRICTED APPLICATION PACKAGES
    Not recomended on paths that are Windows specific like Program Files which might rely on it
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        <#
            PARAMETERS
            _______
            Paths | Array of paths to remove rules on
        #>
        [Parameter(Mandatory, ValueFromPipeline)] [string[]] $Paths
    )

    begin {
        # Prepare identities for whole runtime
        try {
            $AllAppPackages = [Security.Principal.NTAccount]::new("ALL APPLICATION PACKAGES").Translate([System.Security.Principal.SecurityIdentifier])
        } catch {
            Write-Output($_)
            $AllAppPackages = $null
        }
        try {
            $AllRestrictedAppPackages = [Security.Principal.NTAccount]::new("ALL RESTRICTED APPLICATION PACKAGES").Translate([System.Security.Principal.SecurityIdentifier])
        } catch {
            Write-Output($_)
            $AllRestrictedAppPackages = $null
        }
    }

    process {
        # Removes "APPLICATION PACKAGES" ACL from paths
        foreach ($path in $Paths) {
            try {
                $acl = Get-Acl -LiteralPath $path
                # Disable inheritance and keep inherited rules as base for edition
                $acl.SetAccessRuleProtection($true, $true)
                if ($null -ne $AllAppPackages) {
                    $acl.PurgeAccessRules($AllAppPackages)
                    Write-Output("Prepared purge ALL APP PACKAGES on root: $path")
                }
                if ($null -ne $AllAppPackages) {
                    $acl.PurgeAccessRules($AllRestrictedAppPackages)
                    Write-Output("Prepared purge ALL RESTRICTED APP PACKAGES on root: $path")
                }
                Set-Acl -LiteralPath $path -AclObject $acl
                Write-Output("Purge success on root: $path")
            }
            catch {
                Write-Output("Cannot purge on root: $path")
            }
        }
    }
}

#------- EXECUTION -------

$foundClient = $listOfPossibleClientAccounts | Get-ActiveUser
if ($null -eq $foundClient)
{
    exit -1
}
$clientIdentity = $env:computername + "\" + $foundClient
# remove "Authenticated Users" from all drives
Remove-AclForUser -Identities "Authenticated Users" -Value Allow -Paths $available_drives

# Disable full access for Client account for paths:
$path_C = @(
    "C:\VIDEO",
    "C:\DBCAMERA",
    "C:\EZVideoPlayerMovies"
)
Set-AclRule -Identity $clientIdentity -Rule FullControl -Value Deny -InheritanceFlags ContainerInherit,ObjectInherit -Paths $path_C -RecurseInherit

# Deny Full access for Client on all drives excluding C
foreach ($drive in $available_drives) {
    if ($drive -eq 'C:\') {
        continue
    } else {
        Set-AclRule -Identity $clientIdentity -Rule FullControl -Value Deny -InheritanceFlags ContainerInherit,ObjectInherit -Paths $drive
    }
}

# Remove all recycle bins
$recycleBins = $available_drives | ForEach-Object {"$_`$Recycle.Bin"}
foreach ($recycleBin in $recycleBins) {
    if ((Test-Path -LiteralPath $recycleBin) -eq $True) {
        Remove-Item -LiteralPath $recycleBin -Recurse -Force
    }
}

# Disable full access for Client account for paths:
$pathSetDeny = @(
    "C:\Program` Files` (x86)\EZUniverse",
    "C:\Program` Files\EZUniverse",
    "C:\onstartup"
    #"C:\OnStartup"
)
Remove-ApplicationPackagesFromAcl -Paths $pathSetDeny
Remove-AclForUser -Identities @('Everyone','Users',$clientIdentity) -Paths $pathSetRemove -RecurseInherit
Set-AclRule -Identity $clientIdentity -Rule FullControl -Value Deny -Paths $pathSetDeny -InheritanceFlags ContainerInherit,ObjectInherit -RecurseInherit

# Remove all deny rules for Client user and set Read and Execute rule
$pathSetRemove = @(
    "C:\Program` Files` (x86)\EZUniverse\360iQViewer",
    "C:\Program` Files` (x86)\EZUniverse\360iQPVMController"
)
Remove-ApplicationPackagesFromAcl -Paths $pathSetRemove
Remove-AclForUser -Identities @('Everyone','Users',$clientIdentity) -Paths $pathSetRemove -RecurseInherit
Set-AclRule -Identity $clientIdentity -Rule ReadAndExecute -Value Allow -InheritanceFlags ContainerInherit,ObjectInherit -Paths $pathSetRemove -RecurseInherit

# Unlock configuration and log files for Client account
$configurationFiles = @(
    "C:\Program` Files` (x86)\EZUniverse\360iQViewer\ConfigurationBackup",
    "C:\Program` Files` (x86)\EZUniverse\360iQViewer\Logs",
    "C:\Program` Files` (x86)\EZUniverse\360iQPVMController\configuration.json",
    "C:\Program` Files` (x86)\EZUniverse\360iQPVMController\Logs"
)
Set-AclRule -Identity $clientIdentity -Rule Modify -Value Allow -Paths $configurationFiles -RecurseInherit

# Add LOCAL SERVICE to PreParser as it is runnning in this context instead of SYSTEM as all services
$configPreParser = @(
    "C:\Program` Files` (x86)\EZUniverse\EZ360Controller\EZ360PreParser"
)
Set-AclRule -Identity 'LOCAL SERVICE' -Rule FullControl -Value Allow -Paths $configPreParser -InheritanceFlags ContainerInherit,ObjectInherit -RecurseInherit
