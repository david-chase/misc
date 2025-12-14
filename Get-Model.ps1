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

# Check for help request
if( ( $sModel -eq "/?" ) -or ( ( -not $sModel ) -and ( -not $query ) -and ( -not $any ) -and ( -not $all ) -and ( -not $none ) ) ) {
    Write-Host ""
    Write-Host "Get-Model.ps1 - Search, add, and modify entries in the Models database" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  Get-Model <modelname>              - Find exact match (case-insensitive)"
    Write-Host "  Get-Model <pattern>                - Find using wildcards (* and ?)"
    Write-Host "  Get-Model <modelname> -update      - Update an existing model"
    Write-Host "  Get-Model <modelname> -remove      - Remove a model"
    Write-Host ""
    Write-Host "QUERY MODE:" -ForegroundColor Yellow
    Write-Host "  Get-Model -query -any `"#tag1#tag2`"  - Find models with ANY of the tags"
    Write-Host "  Get-Model -query -all `"#tag1#tag2`"  - Find models with ALL of the tags"
    Write-Host "  Get-Model <pattern> -query -all `"#tag1#tag2`" - Combine model filter with tags"
    Write-Host ""
    Write-Host "WILDCARDS:" -ForegroundColor Yellow
    Write-Host "  *  - Matches zero or more characters (e.g., 'gpt*', '*model*')"
    Write-Host "  ?  - Matches exactly one character (e.g., 'model?', 'gpt-?')"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  Get-Model mochi-1"
    Write-Host "  Get-Model mochi*"
    Write-Host "  Get-Model `"*gpt*`""
    Write-Host "  Get-Model mochi* -query -all `"#redhead#pretty`""
    Write-Host "  Get-Model -query -any `"#fast#cheap`""
    Write-Host ""
    Exit
}

# Inspect command line
if( $q ) { $query = $true }
if( ( -not $sModel ) -and ( -not $query ) ) { Write-Host "Cannot leave model name blank unless using -query operator" -ForegroundColor Red; Exit; }
if( ( $any -or $all -or $none ) -and ( -not $query ) ) { Write-Host "Cannot use -any, -all, or -none operators without -query operator" -ForegroundColor Red; Exit; }

# Prep to call the DB query
$sCollection = "Models"

# Start building a query string
if( $query ) {
    $sQuery = "SELECT * FROM " + $sCollection + " c WHERE "
    $bFirstClause = $true
    
    # Process the -any operator
    if( $any ) {
        $bFirstClause = $false 
        
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
        if( -not $bFirstClause ) { $sQuery += " AND " }
        $bFirstClause = $false

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
    # Check if the model name contains wildcards (* or ?)
    if( $sModel -match '[\*\?]' ) {
        # Convert wildcards to regex pattern: * becomes .*, ? becomes .
        # First escape special regex characters, then replace our escaped wildcards
        $sRegexPattern = [regex]::Escape($sModel)
        $sRegexPattern = $sRegexPattern -replace '\\\*', '.*' -replace '\\\?', '.'
        $sQuery = "SELECT * FROM " + $sCollection + " c WHERE RegexMatch(c.name, '" + $sRegexPattern + "', 'i')"
    } else {
        # Exact match (case-insensitive)
        $sQuery = "SELECT * FROM " + $sCollection + " c WHERE STRINGEQUALS(c.name, '" + $sModel + "', true)"
    }
} # END if( $query )

# Query the database
$aResults = Query-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadOnlyKey -Query $sQuery

# If in query mode with a model name specified, filter results by model name
if( $query -and $sModel ) {
    # Check if the model name contains wildcards (* or ?)
    if( $sModel -match '[\*\?]' ) {
        # Convert wildcards to regex pattern
        $sRegexPattern = [regex]::Escape($sModel)
        $sRegexPattern = $sRegexPattern -replace '\\\*', '.*' -replace '\\\?', '.'
        $aResults = $aResults | Where-Object { $_.name -match "^$sRegexPattern`$" }
    } else {
        # Exact match (case-insensitive)
        $aResults = $aResults | Where-Object { $_.name -eq $sModel }
    }
} # END if( $query -and $sModel )

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

    # Can't do a remove if multiple matches
    if( $aResults.Count -ne 1 ) {
        Write-Host "Can't perform a remove when the query returns multiple records. Only 1 record must match." -ForegroundColor Red; Exit;
    }

    if( ( Read-Host -Prompt "Remove model? [y/N]" ).ToUpper() -eq "Y" ) {
        
        $aResults = Remove-CosmosDb -EndPoint $sDBEndpoint -DBName $sDBName -Collection $sCollection -Key $sReadWriteKey -PartitionKey $sModel -DocId $aResults.id

    } # END if( ( Read-Host -Prompt "Remove model? [y/N]" ).ToUpper() -eq "Y" )

} # END remove