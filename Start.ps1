$customer = [PSCustomObject]@{
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
	LegalParties = @(
		@{
			LegalPartyId = 11
			Name = 'LP_11'
		},
		@{
			LegalPartyId = 12
			Name = 'LP_12'
		}
	)
	LogonUsers = @(
		@{
			LogonUserId = 20
			Username = 'username1'
			LinkedToLegalPartyId = @(11,12)
		},
		@{
			LogonUserId = 21
			Username = 'username2'
			LinkedToLegalPartyId = @(12)
		}
	)
}

# c# can tell us assembly name
# Console.WriteLine(typeof(System.Xml.XmlDocument).Assembly.FullName);

$path = Join-Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) "bpm_xsd.dll"
Add-Type -AssemblyName "System.Xml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089"
# Add-Type -Namespace "bpm" -TypeName "BPMNDiagram" -AssemblyName $path -PassThru
Add-Type -path $path

# absolute path needed :(
# [Reflection.Assembly]::LoadFile(".\bpm_xsd.dll")


function ToCollaboration($customer)
{
	$participant = New-Object -TypeName bpm.tParticipant -Property (@{
		'id'='Participant_customer_'+$customer.ClientCode;
		'name'='Customer_'+$customer.ClientCode;
		'processRef'='Process_'+$customer.ClientCode;
	})

	$collab = New-Object -TypeName bpm.tCollaboration -Property (@{
		'id'='Collaboration_customer_'+ $customer.ClientCode;
		'participant'= @($participant)
	})
	return $collab
}

function ToTask([string]$id, [string]$name)
{
	#Write-Verbose "Task_$id_$name"
	New-Object -TypeName bpm.tTask -Property (@{
		'id'="Task-$name-$id";
		'name'="$name $id";
		}) 
}

function ToSequenceflow($source, $target, $name)
{
	$flow = New-Object -TypeName bpm.tSequenceFlow -Property (@{
		'id'="Sequenceflow-from-$($source.Id)-to-$($target.Id)";
		'sourceRef'= $source.Id;
		'targetRef'=$target.Id;
		})
	if(![string]::IsNullOrEmpty($name))
	{
		$flow.name = $name;
	}
	return $flow;
}

function ToProcess($customer)
{
	$tas = $customer.TradingAccounts | 
		% { $_.TradingAccountId } |
		% { $p1=@()} {$p1+= "Task_{0}" -f $_ } {$p1 -join ',' }
	[string[]] $flowNodes = 
		'Task_'+$customer.ClientAccountId,
		'Task_'+$customer.ContractId#,
		#$tas

	$parties =
		$customer.LegalParties |
		% { ToTask $($_.LegalPartyId) $($_.Name) }
	$logons =
		$customer.LogonUsers |
		% { ToTask $($_.LogonUserId) $($_.Username) }

	# clientaccount to contract
	# contracts to legal parties

	$contract = ToTask $customer.ContractId 'Contract'
	$clientAccount = ToTask $customer.ClientAccountId 'ClientAccount'

	$seq1 = ToSequenceflow $contract $clientAccount $null

	$items = @(
		@($contract, $clientAccount),
		@($parties),
		@($logons),
		@($seq1)
	) |
	% { $_ } # flatten

	$laneset = New-Object -TypeName bpm.tLaneSet -Property (@{
		'id'='LaneSet_'+$customer.ClientCode;
		'lane'= @(
			New-Object bpm.tLane -Property (@{
				'id'='Lane_'+$customer.ClientCode;
				'flowNodeRef'= $flowNodes;
				}));		
	})

	$process = New-Object -TypeName bpm.tProcess -Property (@{
		'id'='Process_'+$customer.ClientCode;
		'isExecutable'=$false;
		'laneSet'=@($laneset);
		'items'=$items
	})
	return $process
}

function Serialize($definitions)
{
	$serializer = New-Object -typeName System.Xml.Serialization.XmlSerializer($definitions.GetType(), "http://bpmn.io/schema/bpmn")
    $ms = New-Object -typeName System.IO.MemoryStream
	$writerSettings = New-Object -TypeName System.Xml.XmlWriterSettings -Property (@{
		'Encoding'= [System.Text.Encoding]::UTF8;
		'CloseOutput'= $true;
		'Indent' = $true;
	})
    $writer = [System.Xml.XmlWriter]::Create($ms, $writerSettings)
                
	Write-Verbose "Creating output.xml file..."
    $ns = new-object -typename System.Xml.Serialization.XmlSerializerNamespaces
    $ns.Add("","");
    $ns.Add("bpmn", "http://www.omg.org/spec/BPMN/20100524/MODEL");
	$ns.Add("bpmni", "http://www.omg.org/spec/BPMN/20100524/DI");
	$ns.Add("dc", "http://www.omg.org/spec/DD/20100524/DC");
	$ns.Add("di", "http://www.omg.org/spec/DD/20100524/DI");
    $ns.Add("xsi", "http://www.w3.org/2001/XMLSchema-instance");
    
	$serializer.Serialize($writer, $definitions, $ns)
    
	$ms.Position = 0
	$streamReader = New-Object -TypeName System.IO.StreamReader($ms)
	$data = $streamReader.ReadToEnd()

	$ms.Close
	return $data
}

$xml = New-Object -TypeName bpm.tDefinitions -Property (@{
	'Items'= @(		
		(ToCollaboration($customer)),
		(ToProcess($customer))
	)
})

Write-Output (Serialize $xml)