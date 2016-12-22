Function Get-ComputerNameFromInstance {
    [CmdletBinding()]
    Param(          
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server instance.')]
        [string]$Instance
    ) 
    If ($Instance){$ComputerName = $Instance.split('\')[0].split(',')[0]}
    else{$ComputerName = $env:COMPUTERNAME}
    Return $ComputerName
}
Function  Get-SQLConnectionObject {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server or domain account to authenticate with.')]
        [string]$Username,
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server or domain account password to authenticate with.')]
        [string]$Password,
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server instance to connection to.')]
        [string]$Instance,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Dedicated Administrator Connection (DAC).')]
        [Switch]$DAC,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Default database to connect to.')]
        [String]$Database,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Connection timeout.')]
        [string]$TimeOut = 1
    )
    Begin {           
        if($DAC){$DacConn = 'ADMIN:'}else{$DacConn = ''}
        if(-not $Database){$Database = 'Master'}
    } Process {
        if (-not $Instance) { $Instance = $env:COMPUTERNAME }
        $Connection = New-Object -TypeName System.Data.SqlClient.SqlConnection
        if(-not $Username) {
            $AuthenticationType = "Current Windows Credentials"
            $Connection.ConnectionString = "Server=$DacConn$Instance;Database=$Database;Integrated Security=SSPI;Connection Timeout=1"
        }
        elseif ($username -like "*\*") {
            $AuthenticationType = "Provided Windows Credentials"
            $Connection.ConnectionString = "Server=$DacConn$Instance;Database=$Database;Integrated Security=SSPI;uid=$Username;pwd=$Password;Connection Timeout=$TimeOut"
        }
        elseif (($username) -and ($username -notlike "*\*")) {
            $AuthenticationType = "Provided SQL Login"
            $Connection.ConnectionString = "Server=$DacConn$Instance;Database=$Database;User ID=$Username;Password=$Password;Connection Timeout=$TimeOut"
        }
        Write-Host ($Connection.Database)
        return $Connection
    } End {                
    }
}
Function Get-SQLConnectionTest {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server or domain account to authenticate with.')]
        [string]$Username,
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server or domain account password to authenticate with.')]
        [string]$Password,
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server instance to connection to.')]
        [string]$Instance,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Connect using Dedicated Admin Connection.')]
        [Switch]$DAC,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Default database to connect to.')]
        [String]$Database,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Connection timeout.')]
        [string]$TimeOut
    )
    Begin {
        $TblResults = New-Object -TypeName System.Data.DataTable
        $null = $TblResults.Columns.Add('ComputerName')
        $null = $TblResults.Columns.Add('Instance')
        $null = $TblResults.Columns.Add('Status')
    } Process {
        if(-not $Instance) { $Instance = $env:COMPUTERNAME }
        $ComputerName = Get-ComputerNameFromInstance -Instance $Instance
        if($DAC) {
            $Connection = Get-SQLConnectionObject -Instance $Instance -Username $Username -Password $Password -DAC -TimeOut $TimeOut -Database $Database
        } else {
            $Connection = Get-SQLConnectionObject -Instance $Instance -Username $Username -Password $Password -TimeOut $TimeOut -Database $Database
        }
        try {
            $Connection.Open()
            $null = $TblResults.Rows.Add("$ComputerName","$Instance",'Accessible')
            $Connection.Close()
            $Connection.Dispose()
        } catch {
            $ErrorMessage = $_.Exception.Message
            "$Instance : Connection Failed."
            "Error: $ErrorMessage"
        }
            $null = $TblResults.Rows.Add("$ComputerName","$Instance",'Not Accessible')
    } End {
        $TblResults
    }
}
Function  Get-SQLQuery {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server or domain account to authenticate with.')]
        [string]$Username,
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server or domain account password to authenticate with.')]
        [string]$Password,
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server instance to connection to.')]
        [string]$Instance,
        [Parameter(Mandatory = $false,        
        HelpMessage = 'SQL Server query.')]
        [string]$Query,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Connect using Dedicated Admin Connection.')]
        [Switch]$DAC,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Default database to connect to.')]
        [String]$Database,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Connection timeout.')]
        [int]$TimeOut,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Return error message if exists.')]
        [switch]$ReturnError
    )
    Begin {
        $TblQueryResults = New-Object -TypeName System.Data.DataTable
    } Process {      
        if($DAC){$Connection = Get-SQLConnectionObject -Instance $Instance -Username $Username -Password $Password -TimeOut $TimeOut -DAC -Database $Database}
        else{$Connection = Get-SQLConnectionObject -Instance $Instance -Username $Username -Password $Password -TimeOut $TimeOut -Database $Database}
        $ConnectionString = $Connection.Connectionstring
        $Instance = $ConnectionString.split(';')[0].split('=')[1]
        if($Query) {
            $Connection.Open()
            "$Instance : Connection Success."
            $Command = New-Object -TypeName System.Data.SqlClient.SqlCommand -ArgumentList ($Query, $Connection)
            try {
                $Results = $Command.ExecuteReader()                                             
                $TblQueryResults.Load($Results)  
            } catch {
                #pass
            }                                                                                    
            $Connection.Close()
            $Connection.Dispose() 
        }
        else{'No query provided to Get-SQLQuery function.';Break}
    } End {   
        if($ReturnError){$ErrorMessage}
        else{$TblQueryResults}                  
    }
}
Function  Get-SQLColumn {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server or domain account to authenticate with.')]
        [string]$Username,
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server or domain account password to authenticate with.')]
        [string]$Password,
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server instance to connection to.')]
        [string]$Instance,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Database name.')]
        [string]$DatabaseName,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Table name.')]
        [string]$TableName,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Filter by exact column name.')]
        [string]$ColumnName,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Column name using wildcards in search.  Supports comma seperated list.')]
        [string]$ColumnNameSearch,
        [Parameter(Mandatory = $false,
        HelpMessage = "Don't select tables from default databases.")]
        [switch]$NoDefaults
    )
    Begin {
        $TblColumns = New-Object -TypeName System.Data.DataTable
        if($TableName) {
            $TableNameFilter = " and TABLE_NAME like '%$TableName%'"
        } else {
            $TableNameFilter = ''
        }
        if($ColumnName) {
            $ColumnFilter = " and column_name like '$ColumnName'"
        } else {
            $ColumnFilter = ''
        }
        if($ColumnNameSearch) {
            $ColumnSearchFilter = " and column_name like '%$ColumnNameSearch%'"
        } else {
            $ColumnSearchFilter = ''
        }
        if($ColumnNameSearch) {
            $Keywords = $ColumnNameSearch.split(',')
            [int]$i = $Keywords.Count
            while ($i -gt 0) {
                $i = $i - 1
                $Keyword = $Keywords[$i]
                if($i -eq ($Keywords.Count -1)) {
                    $ColumnSearchFilter = "and column_name like '%$Keyword%'"
                } else {
                    $ColumnSearchFilter = $ColumnSearchFilter + " or column_name like '%$Keyword%'"
                }
            }
        }
    } Process {
        $ComputerName = Get-ComputerNameFromInstance -Instance $Instance
        if(-not $Instance) { $Instance = $env:COMPUTERNAME }
        $TestConnection = Get-SQLConnectionTest -Instance $Instance -Username $Username -Password $Password | ? -FilterScript { $_.Status -eq 'Accessible' }
        $TestConnection
        if($TestConnection) {
            "$Instance : Connection Success."
        } else {
            "$Instance : Connection Failed."
            return
        }
        if($NoDefaults) {
            $TblDatabases = Get-SQLDatabase -Instance $Instance -Username $Username -Password $Password -DatabaseName $DatabaseName -HasAccess -NoDefaults
        } else {
            $TblDatabases = Get-SQLDatabase -Instance $Instance -Username $Username -Password $Password -DatabaseName $DatabaseName -HasAccess
        }
        $TblDatabases | % -Process {
            $DbName = $_.DatabaseName
            $Query = "  USE $DbName;
                SELECT  '$ComputerName' as [ComputerName],
                '$Instance' as [Instance],
                TABLE_CATALOG AS [DatabaseName],
                TABLE_SCHEMA AS [SchemaName],
                TABLE_NAME as [TableName],
                COLUMN_NAME as [ColumnName],
                DATA_TYPE as [ColumnDataType],
                CHARACTER_MAXIMUM_LENGTH as [ColumnMaxLength]
                FROM	[$DbName].[INFORMATION_SCHEMA].[COLUMNS] WHERE 1=1
                $ColumnSearchFilter
                $ColumnFilter
                $TableNameFilter
                ORDER BY TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME"
            $TblResults = Get-SQLQuery -Instance $Instance -Query $Query -Username $Username -Password $Password
            $TblColumns = $TblColumns + $TblResults
        }
    } End {
        $TblColumns
    }
}
Function Get-SQLColumnSampleData {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server or domain account to authenticate with.')]
        [string]$Username,
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server or domain account password to authenticate with.')]
        [string]$Password,
        [Parameter(Mandatory = $false,
        HelpMessage = 'SQL Server instance to connection to.')]
        [string]$Instance,
        [Parameter(Mandatory = $false,
        HelpMessage = "Don't output anything.")]
        [switch]$NoOutput,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Number of records to sample.')]
        [int]$SampleSize = 1,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Comma seperated list of keywords to search for.')]
        [string]$Keywords = 'Password',
        [Parameter(Mandatory = $false,
        HelpMessage = 'Database name to filter on.')]
        [string]$DatabaseName,
        [Parameter(Mandatory = $false,
        HelpMessage = 'Use Luhn formula to check if sample is a valid credit card.')]
        [switch]$ValidateCC,
        [Parameter(Mandatory = $false,
        HelpMessage = "Don't select tables from default databases.")]
        [switch]$NoDefaults
    )
    Begin {
        $TblData = New-Object -TypeName System.Data.DataTable
        $null = $TblData.Columns.Add('ComputerName')
        $null = $TblData.Columns.Add('Instance')
        $null = $TblData.Columns.Add('Database')
        $null = $TblData.Columns.Add('Schema')
        $null = $TblData.Columns.Add('Table')
        $null = $TblData.Columns.Add('Column')
        $null = $TblData.Columns.Add('Sample')
        $null = $TblData.Columns.Add('RowCount')
        if($ValidateCC) { $null = $TblData.Columns.Add('IsCC') }
    } Process {
        $ComputerName = Get-ComputerNameFromInstance -Instance $Instance
        if(-not $Instance) { $Instance = $env:COMPUTERNAME }
        $TestConnection = Get-SQLConnectionTest -Instance $Instance -Username $Username -Password $Password | ? -FilterScript { $_.Status -eq 'Accessible' }
        if(-not $TestConnection) {
            "$Instance : CONNECTION FAILED"
            Return
        }
        else {
            "$Instance : START SEARCH DATA BY COLUMN"
            "$Instance : - Connection Success."
            "$Instance : - Searching for column names that match criteria..."
            if($NoDefaults) {
                $Columns = Get-SQLColumn -Instance $Instance -Username $Username -Password $Password -DatabaseName $DatabaseName -ColumnNameSearch $Keywords -NoDefaults
            } else {
                $Columns = Get-SQLColumn -Instance $Instance -Username $Username -Password $Password -DatabaseName $DatabaseName -ColumnNameSearch $Keywords 
            }
        }
        if($Columns) {
            $Columns | % -Process {
                $sDatabaseName = $_.DatabaseName
                $sSchemaName = $_.SchemaName
                $sTableName = $_.TableName
                $sColumnName = $_.ColumnName
                $AffectedColumn = "[$sDatabaseName].[$sSchemaName].[$sTableName].[$sColumnName]"
                $AffectedTable = "[$sDatabaseName].[$sSchemaName].[$sTableName]"
                $Query = "USE $sDatabaseName; SELECT TOP $SampleSize [$sColumnName] FROM $AffectedTable WHERE [$sColumnName] is not null"
                $QueryRowCount = "USE $sDatabaseName; SELECT count(CAST([$sColumnName] as VARCHAR(200))) as NumRows FROM $AffectedTable WHERE [$sColumnName] is not null"
                if( -not $SuppressVerbose) {
                    "$Instance : - Column match: $AffectedColumn"
                    "$Instance : - Selecting $SampleSize rows of data sample from column $AffectedColumn."
                }
                $RowCount = Get-SQLQuery -Instance $Instance -Username $Username -Password $Password -Query $QueryRowCount | select -Property NumRows -ExpandProperty NumRows
                Get-SQLQuery -Instance $Instance -Username $Username -Password $Password -Query $Query | select -ExpandProperty $sColumnName | % -Process {
                    if($ValidateCC) {
                        $Value = 0
                        if([uint64]::TryParse($_,[ref]$Value)) {
                            $LuhnCheck = Test-IsLuhnValid $_ -ErrorAction SilentlyContinue
                        } else {
                            $LuhnCheck = 'False'
                        }
                        $null = $TblData.Rows.Add($ComputerName, $Instance, $sDatabaseName, $sSchemaName, $sTableName, $sColumnName, $_, $RowCount, $LuhnCheck)
                    } else {
                        $null = $TblData.Rows.Add($ComputerName, $Instance, $sDatabaseName, $sSchemaName, $sTableName, $sColumnName, $_, $RowCount)
                    }
                }
            }
        } else {
                "$Instance : - No columns were found that matched the search."
        }
        "$Instance : END SEARCH DATA BY COLUMN"
    } End {
        return $TblData
    }
}
