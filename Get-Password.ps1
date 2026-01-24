#-------------------------------------------------------------------
#  Get-Password
#  Hit a CosmosDB database with password info, then generate a password
#-------------------------------------------------------------------

Param
(
    [ Parameter( Mandatory = $true ) ] [string] $sSite,
    [switch]$remove = $false,
    [switch]$update = $false,
    [switch]$query = $false,
    [switch]$q = $false,
    [switch]$v = $false
)


# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
. ".\CosmosDB Functions v2.ps1"
Pop-Location

# Do some command line parsing
if( $q ) { $query = $true }

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
    $sQuery = "SELECT * FROM " + $sCollection + " c WHERE CONTAINS( c.site, '" + $sSite + "', true )"
} else {
    $sQuery = "SELECT * FROM " + $sCollection + " c WHERE c.site = '" + $sSite + "'"
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
	`"site`": `"$sSite`",
	`"password`": `"$sPassword`",
	`"complexity`": `"$sComplexity`",
	`"comment`": `"$sComment`"
}
"@ # This can't be preceded by whitespace
        
        $aResults = Post-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadWriteKey -DocumentBody $sJson -PartitionKey $sSite

        # Now output the password

        if( $IsWindows ) { $sOutput = cscript.exe /nologo $sPassGenFile $aMasterPassword.value $sSite $sComplexity }
        if( $IsLinux ) { $sOutput = node $sPassGenFile $aMasterPassword.value $sSite $sComplexity }

        if( $v ) { 
            Write-Host $sOutput }
        else {
            Write-Host "Ok" -ForegroundColor Yellow }
        Set-Clipboard $sOutput 

    } # if ( ( Read-Host -Prompt "Add site? [y/N]" ).ToUpper() -eq "Y" )

    Exit # Don't fall into the rest of the code.  Exit here.

} # END if( $aResults.Count -eq 0 )

# So we now know we got exactly one result

if( $remove ) {
    # User has asked to remove this entry
    if( ( Read-Host -Prompt "Remove site? [y/N]" ).ToUpper() -eq "Y" ) {
            
        $aResults = Remove-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadWriteKey -PartitionKey $sSite -DocId $aResults.id

    } # if ( ( Read-Host -Prompt "Remove site? [y/N]" ).ToUpper() -eq "Y" )

    Exit # Don't fall into the rest of the code.  Exit here.

 } # END if( $remove )

if( $update ) {
    # User wants to update the password
    Write-Host Updating record $sSitedavi -ForegroundColor Cyan
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
	`"site`": `"$sSite`",
	`"account`": `"$sAccount`",
	`"password`": `"$sPassword`",
    `"complexity`": `"$sComplexity`",
    `"comment`": `"$sComment`"
}
"@ # This can't be preceded by whitespace   

    $aResults = Post-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadWriteKey -DocumentBody $sJson -PartitionKey $sSite

    Exit # Don't fall into the rest of the code.  Exit here.
} # END if( $update )

# We've fallen through all other scenarios, so just output the password

# If the password isn't "#" then just return it, otherwise pass them to JavaScript
if( $aResults.password -eq "#" ) { 
    $sOutput = cscript.exe /nologo $sPassGenFile $aMasterPassword.value $aResults.site $aResults.complexity 
            
} else { 
    $sOutput = $aResults.password
}

if( $v ) { 
    Write-Host `n$sOutput -NoNewline -ForegroundColor yellow
    $aResults | Select-Object -Property site, account, password, complexity, comment | Out-Host }
else {
    Write-Host "Ok" -ForegroundColor Yellow }
Set-Clipboard $sOutput 