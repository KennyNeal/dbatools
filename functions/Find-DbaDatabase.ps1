Function Find-DbaDatabase
{
<#
.SYNOPSIS
Find database/s on multiple servers that match critea you input

.DESCRIPTION
Allows you to search SQL Server instances for database that have either the same name, owner or service broker guid.

There a several reasons for the service broker guid not matching on a restored database primarily using alter database new broker. or turn off broker to return a guid of 0000-0000-0000-0000. 

.PARAMETER SqlServer
The SQL Server that you're connecting to.

.PARAMETER SqlCredential
Credential object used to connect to the SQL Server as a different user

.PARAMETER Property
What you would like to search on. Either Database Name, Owner, or Service Broker GUID. Database name is the default.

.PARAMETER Pattern
Value that is searched for. This is a regular expression match but you can just use a plain ol string like 'dbareports'

.PARAMETER Exact
Search for an exact match instead of a pattern

.PARAMETER Detailed
Output a more detailed view showing regular output plus Tables, StoredProcedures, Views and ExtendedProperties to see they closely match to help find related databases.

.NOTES
Tags: DisasterRecovery
Author: Stephen Bennett: https://sqlnotesfromtheunderground.wordpress.com/

dbatools PowerShell module (https://dbatools.io)
Copyright (C) 2016 Chrissy LeMaire
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

.LINK
 https://dbatools.io/Find-DbaDatabase

.EXAMPLE
Find-DbaDatabase -SqlServer "DEV01", "DEV02", "UAT01", "UAT02", "PROD01", "PROD02" -Pattern Report
Returns all database from the SqlInstances that have a database with Report in the name
	
.EXAMPLE
Find-DbaDatabase -SqlServer "DEV01", "DEV02", "UAT01", "UAT02", "PROD01", "PROD02" -Pattern TestDB -Exact -Detailed 
Returns all database from the SqlInstances that have a database named TestDB with a detailed output.

.EXAMPLE
Find-DbaDatabase -SqlServer "DEV01", "DEV02", "UAT01", "UAT02", "PROD01", "PROD02" -Property ServiceBrokerGuid -Pattern '-faeb-495a-9898-f25a782835f5' -Detailed 
Returns all database from the SqlInstances that have the same Service Broker GUID with a deatiled output

#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias("ServerInstance", "SqlInstance")]
		[string[]]$SqlServer,
		[Alias("Credential")]
		[System.Management.Automation.PSCredential]$SqlCredential,
		[ValidateSet('Name', 'ServiceBrokerGuid', 'Owner')]
		[string]$Property = 'Name',
		[parameter(Mandatory = $true)]
		[string]$Pattern,
		[switch]$Exact,
		[switch]$Detailed
	)
	process
	{
		foreach ($instance in $SqlServer)
		{
			try
			{
				Write-Verbose "Connecting to $instance"
				$server = Connect-SqlServer -SqlServer $instance -SqlCredential $sqlcredential
			}
			catch
			{
				Write-Warning "Failed to connect to: $server"
				continue
			}
			
			if ($exact -eq $true)
			{
				$dbs = $server.Databases | Where-Object { $_.$property -eq $pattern }
			}
			else
			{
				try
				{
					$dbs = $server.Databases | Where-Object { $_.$property.ToString() -match $pattern }
				}
				catch
				{
					# they prolly put aterisks thinking it's a like
					$Pattern = $Pattern -replace '\*', ''
					$Pattern = $Pattern -replace '\%', ''
					$dbs = $server.Databases | Where-Object { $_.$property.ToString() -match $pattern }
				}
			}
			
			foreach ($db in $dbs)
			{
				if ($Detailed)
				{
					$extendedproperties = @()
					foreach ($xp in $db.ExtendedProperties)
					{
						$extendedproperties += [PSCustomObject]@{
							Name = $db.ExtendedProperties[$xp.Name].Name
							Value = $db.ExtendedProperties[$xp.Name].Value
						}
					}
					
					if ($extendedproperties.count -eq 0) { $extendedproperties = 0 }
					
					[PSCustomObject]@{
						ComputerName = $server.NetName
						InstanceName = $server.ServiceName
						SqlInstance = $server.Name
						Name = $db.Name
						SizeMB = $db.Size
						Owner = $db.Owner
						CreateDate = $db.CreateDate
						ServiceBrokerGuid = $db.ServiceBrokerGuid
						Tables = ($db.Tables | Where-Object { $_.IsSystemObject -eq $false }).Count
						StoredProcedures = ($db.StoredProcedures | Where-Object { $_.IsSystemObject -eq $false }).Count
						Views = ($db.Views | Where-Object { $_.IsSystemObject -eq $false }).Count
						ExtendedPropteries = $extendedproperties
						Database = $db
					} | Select-DefaultView -ExcludeProperty Database
				}
				else
				{
					[PSCustomObject]@{
						ComputerName = $server.NetName
						InstanceName = $server.ServiceName
						SqlInstance = $server.Name
						Name = $db.Name
						SizeMB = $db.Size
						Owner = $db.Owner
						CreateDate = $db.CreateDate
						Database = $db
					} | Select-DefaultView -ExcludeProperty Database
				}
			}
		}
	}
}
