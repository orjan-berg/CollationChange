$server = '192.168.50.37'
if (-not $cred) {
    $cred = Get-Credential -UserName sa -Message 'Password please'
}

$tmpPath = $env:TEMP

$database = Get-DbaDatabase -SqlInstance $server -SqlCredential $cred -ExcludeSystem | Where-Object { $_.Name -match 'collationproblem' }

$diff = Test-DbaDbCollation -SqlInstance $server -SqlCredential $cred -Database $database.Name
if (-not $diff.IsEqual) {
    Set-DbaDbState -SqlInstance $server -SqlCredential $cred -Database $database.Name -SingleUser
    Set-DbaDbState -SqlInstance $server -SqlCredential $cred -Database $database.Name -MultiUser    
    Invoke-DbaQuery -SqlInstance $server -SqlCredential $cred -Database $database.Name -Query 'ALTER DATABASE [CollationProblem] COLLATE Danish_Norwegian_CI_AS' 
}

Backup-DbaDatabase -SqlInstance $server -SqlCredential $cred -Database $database.Name -Type Full -CopyOnly

$dbProsess = Get-DbaProcess -SqlInstance $server -SqlCredential $cred -Database $database.Name
if ($dbProsess) {
    Stop-DbaProcess -SqlInstance $server -SqlCredential $cred -Database $database.Name -Spid $dbProsess.Spid
}

Set-DbaDbState -SqlInstance $server -SqlCredential $cred -Database $database.Name -SingleUser
Set-DbaDbState -SqlInstance $server -SqlCredential $cred -Database $database.Name -MultiUser
$sql = Invoke-DbaQuery -SqlInstance $server -SqlCredential $cred -Database $database.Name -File '$tmpPath\ChangeCollation.sql'

$script = $sql.script
$script -replace 'GO...',''

$script | Out-File '$tmpPath\Collation_alter_script.sql'

Invoke-DbaQuery -SqlInstance $server -SqlCredential $cred -Database $database.Name -File '$tmpPath\Collation_alter_script.sql'

Restore-DbaDatabase -SqlInstance $server -SqlCredential $cred -Database $database.Name -Path E:\Data\SQL\Backup -WithReplace 

# Copy-DbaDatabase -Source $server -SourceSqlCredential $cred -Destination $server -DestinationSqlCredential $cred -Database CollationProblem -Prefix Newer -BackupRestore -SharedPath E:\Data\SQL\Backup