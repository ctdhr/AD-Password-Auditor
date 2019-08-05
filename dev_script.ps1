Param(
     [parameter(Mandatory=$true,HelpMessage="The Domain Controller to query")][string]$DC,
     [parameter(Mandatory=$true,HelpMessage="The AD Domain to query")][string]$Domain,
     [parameter(Mandatory=$true,HelpMessage="The maximum number of concurrent cracking threads to launch. It is recommended to provide a value below your CPU logical core count")][ValidateRange(1,10)][int]$MaxThreads,
     [parameter(Mandatory=$true,HelpMessage="The directory containing the dictionary files to test out")][System.IO.FileInfo]$WordlistDirectory,
     [parameter(Mandatory=$true,HelpMessage="The directory where the results will be output")][System.IO.FileInfo]$ResultDirectory
)

Write-Host "################################"
Write-Host "#      AD-Password-Auditor     #"
Write-Host "################################"

#=============================================================
# Validating input variables
#=============================================================
Set-Location (Split-Path $MyInvocation.MyCommand.Path)

If (-Not (Test-Path $WordlistDirectory)) {
    Write-Host "Wordlist directory does not exist. Please provide a valid directory. Exiting."
    exit
} ElseIf ( (Get-ChildItem $WordlistDirectory | Measure-Object).Count -eq 0 ) {
    Write-Host "Wordlist directory is empty. Please provide a valid wordlist. Exiting."
    exit
}

If (-Not (Test-Path $ResultDirectory)) {
    Write-Host "Results directory does not exist. Creating it..."
    New-Item $ResultDirectory -ItemType Directory
} ElseIf ((Get-ChildItem $ResultDirectory | Measure-Object).Count -gt 0 ) {
    Write-Host "Results directory is not emplty. Please delete all files before proceding."
    exit
}

[string] $WordlistDirectory = (Resolve-Path $WordlistDirectory)
[string] $ResultDirectory = (Resolve-Path $ResultDirectory)

If (($MaxThreads -le 0) -or ($MaxThreads -ge 11) -or (-Not $MaxThreads -is [int])) {
    Write-Host "The provided maximum thread count is not valid. Please provide an integer between 1 and 10. Exiting."
    exit
}

#=============================================================
# Cracking
#=============================================================
$ExecutionStartTime = Get-Date

$ScriptBlock = {
    Param (
        [System.Object] [Parameter(Mandatory=$true)] $_,
        [string] [Parameter(Mandatory=$true)] $WordlistDirectory,
        [string] [Parameter(Mandatory=$true)] $ResultDirectory,
        [string] [Parameter(Mandatory=$true)] $DC,
        [string] [Parameter(Mandatory=$true)] $Domain
    )

    Set-Location $WordlistDirectory

    $DC_jobvar = $DC.Clone()
    $Domain_jobvar = $Domain.Clone()

    $OutputFile = New-Item -Path $ResultDirectory -Name $_"_crack_result.txt"
    $Dict = Get-Content $_ |  Select-String -Pattern "^\s*$" -NotMatch | ConvertTo-NTHashDictionary
    # ADReplica must be fetched within the scriptblock, it cannot be passed as a parameter or script crashes
    $ADReplica = Get-ADReplAccount -All -Server $DC_jobvar -NamingContext $Domain_jobvar
    $ADReplica | Test-PasswordQuality -WeakPasswordHashes $Dict -ShowPlainTextPasswords | Out-File -FilePath $Outputfile

    Write-Host "`n@" (Get-Date -DisplayHint Time) "- Finished cracking job for wordlist:" $_
}

Get-ChildItem $WordlistDirectory | ForEach-Object {
    Write-Host "`n@" (Get-Date -DisplayHint Time) "- Launching cracking job for wordlist:" $_

    Start-Job -ScriptBlock $ScriptBlock -ArgumentList ($_, $WordlistDirectory, $ResultDirectory, $DC, $Domain)

    # Handle job execution
    While($(Get-Job -State Running).Count -ge $MaxThreads) {
        Get-Job | Wait-Job -Any | Out-Null
    }
    Get-Job -State Completed | % {
        Receive-Job $_ -AutoRemoveJob -Wait
    }
}

# Handle job execution
While ($(Get-Job -State Running).Count -gt 0) {
   Get-Job | Wait-Job -Any | Out-Null
}
Get-Job -State Completed | % {
   Receive-Job $_ -AutoRemoveJob -Wait
}

If ((Get-ChildItem $ResultDirectory | Measure-Object).Count -gt 0 ) {
    # Result directory is not empty. We can assume everything ran correctly.
    $ts = (Get-Date) - $ExecutionStartTime
    Write-Host ("`nTotal exuction time = {0:dd} Days {0:hh} Hours {0:mm} Minutes {0:ss} Seconds" -f $ts)
}
#=============================================================
# Consolidating results in a single file
#=============================================================
$CrackedPasswords = ""
Set-Location $ResultDirectory
Get-ChildItem | ForEach-Object {
    $RawCrackedPasswords = Get-Content -Raw $_ | Select-String -Pattern "Passwords of these accounts have been found in the dictionary:\r\n(.+\r\n)+Historical " -AllMatches | Foreach {$_.Matches} | Foreach {$_.Value} 
    $CrackedPasswords += $RawCrackedPasswords -split "\r" | Select-String -Pattern "Historical","Passwords of these accounts have been found in the dictionary","^\s*$" -NotMatch
}
$OutputFilePath = ($ResultDirectory + "\CONSOLIDATED_CRACKED_CURRENT_PASSWORDS.txt")
$CrackedPasswords.Split("`n").Trim() | Out-File -FilePath $OutputFilePath
Set-Location (Split-Path $MyInvocation.MyCommand.Path)
If (Test-Path $OutputFilePath) {
    Write-Host "`nOutputted consolidated results to "$OutputFilePath
}
#=============================================================
# Done. Exiting.
#=============================================================
Write-Host "Exiting AD Password Auditor."
