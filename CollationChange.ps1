if (-not (Get-Module dbatools -ListAvailable)) {
    Write-Host ('Installing module dbatools for current user')
    Install-Module -Scope CurrentUser -Force
    Write-Host ('Done installing dbatools')
}

Set-DbatoolsInsecureConnection -SessionOnly
Start-Transcript -Path .\transcript.txt -UseMinimalHeader

$server = '192.168.50.37'
$user = 'sa'
if (-not $cred) {
    $cred = Get-Credential -UserName $user -Message 'Password please'
}

$database = Get-Content -Path .\databases.csv 

foreach ($db in $database) {

    $diff = Test-DbaDbCollation -SqlInstance $server -SqlCredential $cred -Database $db
    if (-not $diff.IsEqual) {
        Write-Host ('Changing database to Singel_User ' + $db)
        $dbProsess = Get-DbaProcess -SqlInstance $server -SqlCredential $cred -Database $db
        if ($dbProsess) {
            Stop-DbaProcess -SqlInstance $server -SqlCredential $cred -Database $db -Spid $dbProsess.Spid
        }
        Invoke-DbaQuery -SqlInstance $server -SqlCredential $cred -Database $db -File .\drop_Table_valued_functions.sql
        Set-DbaDbState -SqlInstance $server -SqlCredential $cred -Database $db -SingleUser 
        Backup-DbaDatabase -SqlInstance $server -SqlCredential $cred -Database $db -Type Full -CopyOnly -CompressBackup 
        Set-DbaDbState -SqlInstance $server -SqlCredential $cred -Database $db -MultiUser 
        $sql = 'ALTER DATABASE ' + $db + ' COLLATE Danish_Norwegian_CI_AS' 
        $result = Invoke-DbaQuery -SqlInstance $server -SqlCredential $cred -Database $db -Query $sql 
        
    }
    Write-Host ('Killing sql connections towards database ' + $db)
    $dbProsess = Get-DbaProcess -SqlInstance $server -SqlCredential $cred -Database $db
    if ($dbProsess) {
        Stop-DbaProcess -SqlInstance $server -SqlCredential $cred -Database $db -Spid $dbProsess.Spid
    }
    
    Set-DbaDbState -SqlInstance $server -SqlCredential $cred -Database $db -SingleUser
    Set-DbaDbState -SqlInstance $server -SqlCredential $cred -Database $db -MultiUser
    Write-Host ('Running ChangeCollation.sql in the context of ' + $db)
    $sql = Invoke-DbaQuery -SqlInstance $server -SqlCredential $cred -Database $db -File .\ChangeCollation.sql
    
    $script = $sql.script
    $script -replace 'GO...',''
    
    Write-Host ('Running Collation_alter_script.sql in the context of ' + $db)
    $script | Out-File .\Collation_alter_script.sql
    
    Invoke-DbaQuery -SqlInstance $server -SqlCredential $cred -Database $db -File .\Collation_alter_script.sql
    Test-DbaDbCollation -SqlInstance $server -SqlCredential $cred -Database $db 
    Write-Host ('Done with collation change database ' + $db) 
}    
Stop-Transcript
    

