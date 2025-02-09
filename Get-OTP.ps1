param(
    [Parameter(Mandatory)]
    [string]$account
)

$sPasscode = echo qsysopr | totp-cli generate default $account
Write-Host $sPasscode
Set-Clipboard -Value $sPasscode