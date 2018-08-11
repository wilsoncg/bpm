$client1 = [PSCustomObject]@{
	ClientAccountId = 1
	ClientCode = 'clientCode'
	ContractId = 10
	ContractName = 'ContractName'
	TradingAccounts = @(
		@{
			TradingAccountId = 101
			TradingAccountCode = 'tac01'
		},
		@{
			TradingAccountId = 102
			TradingAccountCode = 'tac02'
		}
	)
	InRelations = @(
		@{
			ContractId = 10
			RelationshipType = 'AccountHolder'
			RelatedPartyId = 11
		},
		@{
			ContractId = 10
			RelationshipType = 'Linked'
			RelatedPartyId = 12
		}
	)
}
$client1

$path = Join-Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) "bpm_xsd.dll"
$path
Add-Type -AssemblyName $path -PassThru

# absolute path needed :(
# [Reflection.Assembly]::LoadFile(".\bpm_xsd.dll")

$xml = New-Object 
Get-Member -InputObject $xsd

#function ToBpmParticipant()