<#
.SYNOPSIS
   Build the Azure B2C Framework, Relying Party, and Custom UI for each defined environment
.DESCRIPTION
   The script replaces the keys with the value configure in the appsettings.json file contains the keys with their values for each environment:
    •Name - contains the environment name which VS code extension uses to create the environment folder (under the environments parent folder). Use your operation system legal characters only.
    •PolicySettings - contains a collection of key-value pair with your settings. In the policy file, use the format of Settings: and the key name, for example {Settings:FacebookAppId}.     
#>
param(
#Input Path containing the appsettings.json and the XML policy files
[Parameter(Mandatory = $true)]
[string]
$FilePath
)

try{
    #Check if appsettings.json is existed under for root folder        
    $AppSettingsFile = "Scripts/settings.json"

    #Create app settings file with default values
    $AppSettingsJson = Get-Content -Raw -Path $AppSettingsFile | ConvertFrom-Json

    #Read all policy files from the root directory            
    $XmlPolicyFiles = Get-ChildItem -r -Path $FilePath -Filter *.xml | % { $_.FullName }
    Write-Verbose "Files found: $XmlPolicyFiles"

    #Get the app settings                        
    $EnvironmentsRootPath = "Environments"

    #Need to remove it first for local dev
    if((Test-Path -Path $EnvironmentsRootPath -PathType Container) -eq $true)
    {
        Remove-Item $EnvironmentsRootPath -Recurse
    }
    New-Item -ItemType Directory -Force -Path $EnvironmentsRootPath | Out-null
    Copy-Item -Path 'Scripts/DeployToB2C.ps1' -Destination $EnvironmentsRootPath

    #Iterate through environments  
    foreach($entry in $AppSettingsJson.Environments)
    {
        Write-Verbose "ENVIRONMENT: $($entry.Name)"

        if($null -eq $entry.PolicySettings){
            Write-Error "Can't generate '$($entry.Name)' environment policies. Error: Accepted PolicySettings element is missing. You may use old version of the appSettings.json file. For more information, see [App Settings](https://github.com/yoelhor/aad-b2c-vs-code-extension/blob/master/README.md#app-settings)"
        }
        else {
            $environmentRootPath = Join-Path $EnvironmentsRootPath $entry.Name

            if((Test-Path -Path $environmentRootPath -PathType Container) -ne $true)
            {
                New-Item -ItemType Directory -Force -Path $environmentRootPath | Out-Null
            }

            #Copy the whole custom ui folder
            Copy-Item -Path(Join-Path $FilePath 'CustomUI') -Destination (Join-Path $environmentRootPath 'CustomUI') -Recurse
            
            #TODO: Update to use settings.json
            #Find and replace Blob URL
            $customUIFiles = Get-ChildItem -Path (Join-Path $environmentRootPath 'CustomUI') -Exclude *.png,*.svg,*.gif,*.WOFF,*.jpg -Recurse -File
           
           
           


            #Iterate through the list of settings
            foreach($subFilePath in $XmlPolicyFiles )
            {
                #Write-Output $subFilePath
                $fileName = Split-Path $subFilePath -leaf
                #Write-Output $fileName

                # Write-Verbose "FILE: $($entry.Name) - $file"

               $policyContent = Get-Content $subFilePath | Out-String
            #    Write-Output $policyContent
                # $policyContent = Get-Content $file | Out-String

                #Replace the rest of the policy settings
                $policySettingsHash = @{}; #ugly hash conversion from psobject so we can access json properties via key
                $entry.PolicySettings.psobject.properties | ForEach-Object{ $policySettingsHash[$_.Name] = $_.Value }
                foreach($key in $policySettingsHash.Keys)
                {
                    Write-Verbose "KEY: $key VALUE: $($policySettingsHash[$key])"
                    $policyContent = $policyContent -replace "\{Settings:$($key)\}", $policySettingsHash[$key]
                }

                #Save the  policy
                $policyContent | Set-Content ( Join-Path $environmentRootPath $fileName )            
            }

        }

        Write-Output "Your policies were successfully exported and stored under the Environment folder ($($entry.Name))."
    }

}
catch{
    Write-Error $_
}