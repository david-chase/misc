#-------------------------------------------------------------------
#  Get-Password
#  Hit a CosmosDB database with password info, then generate a password
#-------------------------------------------------------------------

Param
(
    [string] $site = "",
    [switch]$d = $false,
    [switch]$delete = $false,
    [switch]$update = $false,
    [switch]$query = $false,
    [switch]$q = $false,
    [switch]$v = $false
)

Write-Host
Write-Host ::: Get-Password ::: -ForegroundColor Cyan
Write-Host

# If nothing at all was passed on the command line, show help and exit
if( $PSBoundParameters.Count -eq 0 ) {
    Write-Host "Usage: Get-Password.ps1 -site <site> [-delete] [-d] [-update] [-query] [-q] [-v]"
    Write-Host
    Write-Host "  -site        Name of the site to look up (required)"
    Write-Host "  -delete, -d  Remove the site's entry from the database"
    Write-Host "  -update      Update the site's stored account, password, complexity, or comment"
    Write-Host "  -query, -q   Case-insensitive partial match on site name; lists matches only"
    Write-Host "  -v           Verbose mode; show the full record, including the rendered password, in table format"
    Write-Host

    Exit
} # END if( $PSBoundParameters.Count -eq 0 )

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
. ".\CosmosDB Functions v2.ps1"
Pop-Location

# Outputs the result, and copies the rendered password to the clipboard.
# In verbose mode, shows the underlying record plus the rendered password.
function Write-PasswordResult {
    Param
    (
        [ Parameter( Mandatory = $true ) ] $oResult,
        [ Parameter( Mandatory = $true ) ] [string] $sRenderedPassword
    )

    if( $v ) {
        $oResult | Select-Object -Property site, account, password, complexity, comment, @{ Name = "rendered"; Expression = { $sRenderedPassword } }
    } else {
        Write-Host "Ok" -ForegroundColor Yellow
    }

    if( $IsWindows ) { Set-Clipboard $sRenderedPassword }
    if( $IsLinux )   { wl-copy $sRenderedPassword }

} # END function Write-PasswordResult

# Do some command line parsing
if( $q ) { $query = $true }
if( $d ) { $remove = $true }
if( $delete ) { $remove = $true }

# We're starting by finding out the master password which is stored in the Secrets table
$sCollection = "Secrets"
$sQuery = "SELECT * FROM Secrets c WHERE c.name = 'masterpassword'"

# Query my master password
$aMasterPassword = Query-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadOnlyKey -Query $sQuery 

$sPassGenFile = $PSScriptRoot + [IO.Path]::DirectorySeparatorChar + "Get-Password.js"

# Now setup the main query
$sCollection = "Passwords"

# If this is a -query we want to do a case-insensitive "LIKE" but an exact match if not a -query
if( $query ) {
    $sQuery = "SELECT * FROM " + $sCollection + " c WHERE CONTAINS( c.site, '" + $site + "', true )"
} else {
    $sQuery = "SELECT * FROM " + $sCollection + " c WHERE c.site = '" + $site + "'"
} # END if( $query )

$aResults = Query-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadOnlyKey -Query $sQuery

# If this was a query all we do is dump the results to screen and exit.  Same if there were multiple results
if( $query -or ( $aResults.Documents.Count -gt 1 ) ) {
    $aResults | Select-Object -Property site, account, password, complexity, comment

    Exit # Don't fall into the rest of the code.  Exit here.
} # END if( $query )


# Check if no results were returned at all
if( $aResults.Count -eq 0 ) {
    # No results returned, so ask if the user wants to add it.
    Write-Host "Site does not exist in database" -ForegroundColor Red
    if( ( Read-Host -Prompt "Add site? [y/N]" ).ToUpper() -eq "Y" ) {
        # User asked us to add this to the database
        $sPassword = Read-Host -Prompt "Enter password [#]"
        if( $sPassword -eq "" ) { $sPassword = "#" }
        $sComplexity = Read-Host -Prompt "Enter complexity [10MNP]"
        if( $sComplexity -eq "" ) { $sComplexity = "10MNP" }
        $sComment = Read-Host -Prompt "Enter comment [BLANK]"
        if( $sComment -eq "" ) { $sComment = "" }

        $sJson = @"
{
	`"id`" : `"$([Guid]::NewGuid().ToString())`",
	`"site`": `"$site`",
	`"password`": `"$sPassword`",
	`"complexity`": `"$sComplexity`",
	`"comment`": `"$sComment`"
}
"@ # This can't be preceded by whitespace
        
        $aResults = Post-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadWriteKey -DocumentBody $sJson -PartitionKey $site

        # Now output the password

        if( $IsWindows ) { $sOutput = cscript.exe /nologo $sPassGenFile $aMasterPassword.value $site $sComplexity }
        if( $IsLinux ) { $sOutput = node $sPassGenFile $aMasterPassword.value $site $sComplexity }

        Write-PasswordResult -oResult $aResults -sRenderedPassword $sOutput

    } # if ( ( Read-Host -Prompt "Add site? [y/N]" ).ToUpper() -eq "Y" )

    Exit # Don't fall into the rest of the code.  Exit here.

} # END if( $aResults.Count -eq 0 )

# So we now know we got exactly one result

if( $remove ) {
    # User has asked to remove this entry
    if( ( Read-Host -Prompt "Remove site? [y/N]" ).ToUpper() -eq "Y" ) {
            
        $aResults = Remove-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadWriteKey -PartitionKey $site -DocId $aResults.id

    } # if ( ( Read-Host -Prompt "Remove site? [y/N]" ).ToUpper() -eq "Y" )

    Exit # Don't fall into the rest of the code.  Exit here.

 } # END if( $remove )

if( $update ) {
    # User wants to update the password
    Write-Host Updating record $site -ForegroundColor Cyan
    $sId = $aResults.id
    $sTempAccount = $aResults.account
    $sTempPassword = $aResults.password
    $sTempComplexity = $aResults.complexity
    $sTempComment = $aResults.comment

    $sAccount = Read-Host -Prompt "Enter account name [$sTempAccount]"
    if( -not $sAccount ) { $sAccount = $aResults.account }
    $sPassword = Read-Host -Prompt "Enter password [$sTempPassword]"
    if( -not $sPassword ) { $sPassword = $aResults.password }
    $sComplexity = Read-Host -Prompt "Enter complexity string [$sTempComplexity]"
    if( -not $sComplexity ) { $sComplexity = $aResults.complexity }
    $sComment = Read-Host -Prompt "Enter comment [$sTempComment]"
    if( -not $sComment ) { $sComment = $aResults.comment }

    $sJson = @"
{
	`"id`" : `"$sId`",
	`"site`": `"$site`",
	`"account`": `"$sAccount`",
	`"password`": `"$sPassword`",
    `"complexity`": `"$sComplexity`",
    `"comment`": `"$sComment`"
}
"@ # This can't be preceded by whitespace   

    $aResults = Post-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadWriteKey -DocumentBody $sJson -PartitionKey $site

    Exit # Don't fall into the rest of the code.  Exit here.
} # END if( $update )

# We've fallen through all other scenarios, so just output the password

# If the password isn't "#" then just return it, otherwise pass them to JavaScript
if( $aResults.password -eq "#" ) { 
    if( $IsWindows ) { $sOutput = cscript.exe /nologo $sPassGenFile $aMasterPassword.value $aResults.site $aResults.complexity }
    if( $IsLinux ) { $sOutput = node $sPassGenFile $aMasterPassword.value $aResults.site $aResults.complexity }

} else { 
    $sOutput = $aResults.password
}

Write-PasswordResult -oResult $aResults -sRenderedPassword $sOutput