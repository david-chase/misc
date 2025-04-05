#-------------------------------------------------------------------
#  Get-Model
#  Hit a CosmosDB database to look for a model that matches
#-------------------------------------------------------------------

Param
(
    [string]$sModel = "",
    [switch]$query = $false,
    [switch]$q = $false,
    [switch]$update = $false,
    [switch]$remove = $false,
    [string]$all = "",
    [string]$any = "",
    [string]$none= ""
)

# Include functions and parse environment variables
$sSharedFunctions = $env:SharedFunctions
Push-Location $sSharedFunctions
. ".\General Functions v1.ps1"
. ".\CosmosDB Functions v2.ps1"
. ".\Tags Functions v1.ps1"
Pop-Location

# Inspect command line
if( $q ) { $query = $true }
if( ( -not $sModel ) -and ( -not $query ) ) { Write-Host "Cannot leave model name blank unless using -query operator" -ForegroundColor Red; Exit; }
if( ( $any -or $all -or $none ) -and ( -not $query ) ) { Write-Host "Cannot use -any, -all, or -none operators without -query operator" -ForegroundColor Red; Exit; }

# Prep to call the DB query
$sCollection = "Models"

# Start building a query string
if( $query ) {
    $sQuery = "SELECT * FROM " + $sCollection + " c WHERE "
    if( $sModel ) { $sQuery += "CONTAINS( c.name, '" + $sModel + "', true )" }
    
    # Process the -any operator
    if( $any ) {
        # If there was an mode speicific then we first need to drop an AND
        if( $sModel ) { $sQuery += " AND " } 
        
        $sQuery += "( "
        $aTags = $any.Split( "#" )
        $iCurrentTag = 1

        foreach( $sTag in $aTags ) {
        
            if( $iCurrentTag -ne 1 ) {
                $sQuery += "CONTAINS( c.tags, '#" + $sTag + "', true )"
        
                # Add an OR unless this is the last tag
                if( $iCurrentTag -lt $aTags.Count ) {
                    $sQuery += " OR "
                } # END if( $iCurrentTag -lt $aTags.Count )

            } # END if( $iCurrentTag -ne 1 )

            $iCurrentTag++

        } # END foreach( $sTag in $aTags )
    
        $sQuery += " )"
    } # END if( $any )

    if( $all ) {

        # If there was an -any clause then we first need to drop an AND
        if( $any -or $sModel ) { $sQuery += " AND " }

        $sQuery += "( "
        $aTags = $all.Split( "#" )
        $iCurrentTag = 1

        foreach( $sTag in $aTags ) {
        
            if( $iCurrentTag -ne 1 ) {
                $sQuery += "CONTAINS( c.tags, '#" + $sTag + "', true )"
        
                # Add an OR unless this is the last tag
                if( $iCurrentTag -lt $aTags.Count ) {
                    $sQuery += " AND "
                } # END if( $iCurrentTag -lt $aTags.Count )

            } # END if( $iCurrentTag -ne 1 )

            $iCurrentTag++

        } # END foreach( $sTag in $aTags )
    
        $sQuery += " )"
    } # END if( $all )


} else { 
    $sQuery = "SELECT * FROM " + $sCollection + " c WHERE c.name = '" + $sModel + "'"
} # END if( $query )

# Query the database
$aResults = Query-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadOnlyKey -Query $sQuery
$aResults | Select-Object -Property name, tags | Sort-Object -Property name | out-host
Write-Host $aResults.Count matches... -ForegroundColor Cyan

# No match found, ask if I want to add a record
if ( ( -not $aResults ) -and ( -not $query ) ) { 

    if( ( Read-Host -Prompt "Add model? [y/N]" ).ToUpper() -eq "Y" ) {
        $sTags = Read-Host -Prompt "Enter tags [BLANK]"
        $sUrl = Read-Host -Prompt "Enter web link [BLANK]"
        
        # Clean, sort, dedupe
        $sTags = CleanTagString $sTags
        
        $sJson = @"
{
	`"id`" : `"$([Guid]::NewGuid().ToString())`",
	`"name`": `"$sModel`",
	`"tags`": `"$sTags`",
	`"url`": `"$sUrl`"
}
"@ # This can't be preceded by whitespace
        $aResults = Post-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadWriteKey -DocumentBody $sJson -PartitionKey $sModel

        # Check if the user wants to create a folder in models.all
        if( ( Read-Host -Prompt "Create a local folder? [y/N]" ).ToUpper() -eq "Y" ) {
            New-Item -Path $sModelsFolder -Name $sModel -ItemType Directory
        } # END if( ( Read-Host -Prompt "Create a local folder? [y/N]" ).ToUpper() -eq "Y" )

    } # END if( ( Read-Host -Prompt "Add model? [y/N]" ).ToUpper() -eq "Y" )

    Exit # Don't fall into the rest of the code.  Exit here.

} # END if ( -not $aResults )

# The user specified the update option.  Try to update this record
if( $update ) {
    
    # Can't do an update if multiple
    if( $aResults.Count -ne 1 ) {
        Write-Host "Can't perform an update when the query returns multiple records" -ForegroundColor Red; Exit;
    }

    Write-Host Updating record $sModel -ForegroundColor Cyan
    $sId = $aResults.id
    $sTempTags = $aResults.tags
    $sTempUrl = $aResults.url

    $sTags = Read-Host -Prompt "Enter tags [$sTempTags]"
    if( -not $sTags ) { $sTags = $aResults.tags }

    # A silly little hack such that if you type +#tags it will add them rather than overwrite
    $aTags = $sTags.Split( "+", 2 )
    if( $aTags.Count -eq 2 ) {
        $sTags = $aResults.tags + $aTags[ 1 ]
    } # END if( $aTags.Count -eq 2 )

    $sUrl = Read-Host -Prompt "Enter web link [$sTempUrl]"
    if( -not $sUrl ) { $sUrl = $aResults.url }
    # Clean, sort, dedupe
    $sTags = CleanTagString $sTags
    $sJson = @"
{
	`"id`" : `"$sId`",
	`"name`": `"$sModel`",
	`"tags`": `"$sTags`",
	`"url`": `"$sUrl`"
}
"@ # This can't be preceded by whitespace   

    $aResults = Post-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadWriteKey -DocumentBody $sJson -PartitionKey $sModel
    Exit # Don't fall into the rest of the code.  Exit here.

} # END if( $update )

if( $remove ) {

    if( ( Read-Host -Prompt "Remove model? [y/N]" ).ToUpper() -eq "Y" ) {
        
        $aResults = Remove-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadWriteKey -PartitionKey $sModel -DocId $aResults.id

    } # END if( ( Read-Host -Prompt "Remove model? [y/N]" ).ToUpper() -eq "Y" )

} # END remove