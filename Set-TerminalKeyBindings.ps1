
Write-Host ""
Write-Host " ::: Set-TerminalKeybindings.ps1 :::" -ForegroundColor Cyan
Write-Host ""

# Get the default profile ID
$profileId = (gsettings get org.gnome.Terminal.ProfilesList default) -replace "'|uuid-", ""

# Base path to keybindings
$basePath = "org.gnome.Terminal.Legacy.Keybindings:/org/gnome/terminal/legacy/profiles:/:$profileId/"

# Commands to update copy/paste/break behavior
$cmds = @(
    "gsettings set $basePath copy '<Primary>c'",
    "gsettings set $basePath paste '<Primary>v'",
    "gsettings set $basePath close-tab '<Primary><Shift>w'",
    "gsettings set $basePath new-tab '<Primary>t'",
    "gsettings set $basePath new-window '<Primary>n'",
    "gsettings set $basePath find '<Primary>f'",
    "gsettings set $basePath find-next '<Primary>g'",
    "gsettings set $basePath find-previous '<Primary><Shift>g'",
    "gsettings set $basePath reset-and-clear '<Primary><Shift>r'",
    "gsettings set $basePath reset '<Primary>r'",
    "gsettings set $basePath interrupt '<Primary><Shift>c'"
)

Write-Host "Applying GNOME Terminal keybinding changes..." -ForegroundColor Yellow
foreach ($cmd in $cmds) {
    Write-Host "Running: $cmd"
    Invoke-Expression $cmd
}

Write-Host "`nKeybinding configuration complete." -ForegroundColor Green
Write-Host ""

