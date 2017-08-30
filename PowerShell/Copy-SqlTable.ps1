#requires -version 2.0   
###################################
##	This script will copy a table and its data
##	1)	DROP the destination table
## 	2)	CREATE dest table from source table DDL
##	3)	BCP the data from source to destination table
###################################
Param ( 
	[parameter(Mandatory = $true)]  
	[string] $SrcServer, 
	[parameter(Mandatory = $true)]  
	[string] $SrcDatabase, 
	[parameter(Mandatory = $true)]  
	[string] $SrcTable, 
	[parameter(Mandatory = $true)]  
	[string] $DestServer, 
	[string] $DestDatabase, # Name of the destination database is optional. When omitted, it is set to the source database name. 
	[string] $DestTable, 	# Name of the destination table is optional. When omitted, it is set to the source table name.  
	#[switch] $Truncate, 	# Include this switch to truncate the destination table before the copy. 
	[switch] $Create 		# Include this switch to create the table if it doesn't exist at the destination. 
) 

$ErrorActionPreference ="Stop" 
$err=0

function ConnectionString([string] $SrcServer, [string] $DbName)  
{ 
	"Data Source=$SrcServer;Initial Catalog=$DbName;Integrated Security=True;" 
	#Not sure if MultipleActiveResultSets is really needed
	#"Data Source=$SrcServer;Initial Catalog=$DbName;Integrated Security=True;MultipleActiveResultSets=True;" 
} 


function Invoke-Sqlcmd4([string] $ServerInstance, [string] $Query, [string] $ChangeDBName)
{
	#This is a modified version of function in Chad Miller's presentation "PASS AppDev VC - ETL with PowerShell"
	$QueryTimeout=30
	if($Query.Length -eq 0){
		##This needs to be improved to actual error handling, this is my hack crap
		throw "Query is empty"
		#return $false
	}
	
	$conn=new-object System.Data.SqlClient.SQLConnection
	$constring = "Server=" + $ServerInstance + ";Integrated Security=True"
	$conn.ConnectionString=$constring
	#$conn
	$conn.Open()
	$conn.ChangeDatabase("$ChangeDBName")

	if($conn){
		$cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn)
		$cmd.CommandTimeout=$QueryTimeout
		$ds=New-Object system.Data.DataSet
		$da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
		[void]$da.fill($ds)
		$conn.Close()
		$ds.Tables[0]
	}
}


function GetSqlServerObject([string] $Server)
{
	[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
	$srv = New-Object Microsoft.SqlServer.Management.Smo.Server("$Server")
	return $srv
}


function GetScripterObject($srvObj)
{
	#[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
	$scriptor7 = New-Object Microsoft.SqlServer.Management.Smo.Scripter($srvObj)
	return $scriptor7
}


function ScriptTables([String] $Server, [String] $Database, [String] $filePath, [string] $SingleTableName)
{
	[string] $location = ""
	[string] $scrcontent = ""

	$sqlServer = GetSqlServerObject $Server 
	$scriptor = GetScripterObject $sqlServer
		
	$scriptor.Options.NoCollation = $true 
	#$scriptor.Options.ExtendedProperties = $true
	$scriptor.Options.DriIncludeSystemNames = $true 
	
	#This is scaling down the loop so it only goes to a single table since $SrcTable is mandatory, but leaving in for future scalability
	if ($SingleTableName.Length -eq 0){
		$loopObjects=$scriptor.Server.Databases.Item("$Database").Tables
	}
	else {
		$loopObjects=$scriptor.Server.Databases.Item("$Database").Tables.Item("$SingleTableName")
		if ($loopObjects -eq $null) {
			Write-Error "ERROR finding table=$SingleTableName in database=$Database"
		}
	}
	
	Write-Debug "loopobjects=$loopObjects"
	
	foreach ( $table in $loopObjects)  
	{

		if ( ! $location.Length -eq 0 ) {
			$location = $filePath + "\Tables\" + $table.Schema.Replace("\"," ") + "." + $table.Name.Replace("\"," ") + ".sql" 
		}
		$scrcontent = ""

		#Scripting the Drop if it exists
		$scriptor.Options.IncludeIfNotExists = $true 
		$scriptor.Options.ScriptDrops = $true; 
		$scrcontent = $scrcontent + $scriptor.script($table)
		$scriptor.Options.ScriptDrops = $false;

		#Script table Create if not exists (which it won't b/c of drop above) 
		$scriptor.Options.IncludeIfNotExists = $true 
		#$scrcontent = $scrcontent + $scriptor.script($table) +"`r`n"+"Go" +"`r`n"
		$scrcontent = $scrcontent + $scriptor.script($table) +"`r`n"+";" +"`r`n"
		$scriptor.Options.IncludeIfNotExists = $true #false
		
		$Error.Clear()

		foreach ( $Check in $Table.Checks )
		{
			$scriptor.Options.DriChecks = $true
			#$scrcontent =$scrcontent + $scriptor.Script($Check) #+"`r`n"+"Go" +"`r`n"
			$scrcontent =$scrcontent + $scriptor.Script($Check) +"`r`n"+";" +"`r`n"
			$scriptor.Options.DriChecks = $true #--false
		}
		
		$scriptor.Options.DriPrimaryKey = $true 
		$scriptor.Options.DriUniqueKeys = $true 
		foreach ( $Index in $Table.Indexes  )
		{
			$scriptor.Options.IncludeIfNotExists = $true #--true
			#$scrcontent =$scrcontent + $scriptor.Script($Index) #+"`r`n"+"Go" +"`r`n"
			$scrcontent =$scrcontent + $scriptor.Script($Index) +"`r`n"+";" +"`r`n"
		}
		$scriptor.Options.DriPrimaryKey = $true #--false
		$scriptor.Options.DriUniqueKeys = $true #--false

		foreach ( $DmlTrigger in $Table.Triggers )
		{
			$scriptor.Options.IncludeIfNotExists = $true 
			$scriptor.Options.Triggers = $true 
			#$scrcontent =$scrcontent + $scriptor.Script($DmlTrigger) #+"`r`n"+"Go" +"`r`n"
			$scrcontent =$scrcontent + $scriptor.Script($DmlTrigger) +"`r`n"+";" +"`r`n"
			$scriptor.Options.Triggers = $true #--false 
			$scriptor.Options.IncludeIfNotExists = $true #--false
		}
		
		foreach ( $Column in $Table.Columns )
		{
			if ( $Column.DefaultConstraint -ne $null )
			{   
				#$scrcontent =$scrcontent+ $scriptor.Script($Column.DefaultConstraint)# +"`r`n"+"Go" +"`r`n"
				$scrcontent =$scrcontent+ $scriptor.Script($Column.DefaultConstraint) +"`r`n"+";" +"`r`n"
			}
		}
		
		# $scrp.ScriptDrops = $false; 
		# # append create to drop statement
		#$sql += $ind.Script($scrp);  
		
		if ( ! $location.Length -eq 0 ) {
			Out-File -inputobject $scrcontent -filepath $location -encoding "Default"
		}
	}
	
	$scrcontent.ToString() 

}


function CreateTables([string] $server, [string] $database, [string] $sql)
{
	$sqlServer = GetSqlServerObject $server 
	Write-Debug "$sqlServer.Name"
	#Invoke-Sqlcmd3 $sqlServer.Name $sql 
	Invoke-Sqlcmd4 $sqlServer.Name "$sql" $database
}


#$SrcTable="[dbo]."+$SrcTable
Write-Debug "SrcTable=$SrcTable"

$tableSql = ScriptTables $SrcServer $SrcDatabase $filePath $SrcTable 
Write-Debug "tableSql=$tableSql"

CreateTables $DestServer $DestDatabase $tableSql



###############################################################################
########## Main body ##########################################################


###### setup variables ################
If ($DestDatabase.Length –eq 0) { 
	$DestDatabase = $SrcDatabase 
} 

If ($DestTable.Length –eq 0) { 
	$DestTable = $SrcTable 
} 


###### Truncate table if -Truncate ####
If ($Truncate) {  
	$TruncateSql = "TRUNCATE TABLE " + $DestTable 
	Sqlcmd -S $DestServer -d $DestDatabase -Q $TruncateSql 
} 


###### Open data reader ###############
$SrcConnStr = ConnectionString $SrcServer $SrcDatabase 
$SrcConn  = New-Object System.Data.SqlClient.SQLConnection($SrcConnStr) 
$CmdText = "SELECT * FROM " + $SrcTable 
$SqlCommand = New-Object system.Data.SqlClient.SqlCommand($CmdText, $SrcConn)   
$SrcConn.Open() 
[System.Data.SqlClient.SqlDataReader] $SqlReader = $SqlCommand.ExecuteReader() 

###### BCP to server###################
Try 	
{ 
	$DestConnStr = ConnectionString $DestServer $DestDatabase 
	$bulkCopy = New-Object Data.SqlClient.SqlBulkCopy($DestConnStr, [System.Data.SqlClient.SqlBulkCopyOptions]::KeepIdentity) 
	$bulkCopy.DestinationTableName = $DestTable 
	$bulkCopy.WriteToServer($sqlReader) 
} 
Catch [System.Exception] 
{ 
	$ex = $_.Exception 
	Write-Host $ex.Message 
	$err=1
	throw $err
} 
Finally 
{ 
	if (!$err) {
		Write-Host "Table $SrcTable in $SrcDatabase database on $SrcServer has been copied to table $DestTable in $DestDatabase database on $DestServer" 
	}
	$SqlReader.close() 
	$SrcConn.Close() 
	$SrcConn.Dispose() 
	$bulkCopy.Close() 
} 
