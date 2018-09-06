
Enum LegalPartyType
{
	Contract = 1
	Person = 2
}

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
	Relations = @(
		@{
			RelationshipType = 'AccountHolder'
			FromId = 10
			ToId = 11
			FromType = [LegalPartyType]::Contract
			ToType = [LegalPartyType]::Person
		},
		@{
			RelationshipType = 'Linked'
			FromId = 10
			ToId = 12
			FromType = [LegalPartyType]::Contract
			ToType = [LegalPartyType]::Person
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

Enum EntityType
{
	ClientAccount = 1
	Contract = 2
	LegalParty = 3
	Person = 4
	Username = 5
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

function ToTask([string]$id, [string]$name, [EntityType]$type)
{
	$task = New-Object -TypeName bpm.tTask -Property (@{
		'id'="Task-$name-$id";
		'name'="$name $id";
		'tasktype'="{0}" -f $type.value__;
		})
	return $task
}

function TaskAddFlows($task, $outflows, $inflows)
{
	if($outflows -ne $null)
	{
		$task.outgoing = 
			$outflows | % { $_.Id }
	}
	if($inflows -ne $null)
	{
		$task.incoming = 
			$inflows | % { $_.Id }
	}
	return $task
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

function TasksToFlowNodes($tasks)
{
	[string[]] $flowNodes = 
		$tasks | % { $_.Id }
	return $flowNodes
}

function ToProcess($customer)
{
	$parties =
		$customer.LegalParties |
		% { ToTask $($_.LegalPartyId) $($_.Name) ([EntityType]::LegalParty) }
	$logons =
		$customer.LogonUsers |
		% { ToTask $($_.LogonUserId) $($_.Username) ([EntityType]::Username) }

	# clientaccount to contract
	# contracts to legal parties

	$contract = ToTask $customer.ContractId $customer.ContractName ([EntityType]::Contract)
	$clientAccount = ToTask $customer.ClientAccountId $customer.ClientCode ([EntityType]::ClientAccount)

	$seq1 = ToSequenceflow $contract $clientAccount $null
	$sequences = @($seq1)

	# clientaccount outgoing
	$clientAccount = TaskAddFlows $clientAccount $seq1 $null
	# contract incoming/outgoing
	$contract = TaskAddFlows $contract $null $seq1

	$tasks = @(
		@($contract, $clientAccount),
		@($parties),
		@($logons)
	) |
	% { $_ } # flatten

	$items = $tasks + $sequences

	$laneset = New-Object -TypeName bpm.tLaneSet -Property (@{
		'id'='LaneSet_'+$customer.ClientCode;
		'lane'= @(
			New-Object bpm.tLane -Property (@{
				'id'='Lane_'+$customer.ClientCode;
				'flowNodeRef'= TasksToFlowNodes $tasks;
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

function ToShape($id, $x, $y, $width, $height)
{
	return New-Object -TypeName bpm.BPMNShape -Property (@{
		'id'=$id+'_di';
		'bpmnElement'=$id;
		'Bounds'= New-Object -TypeName bpm.Bounds -Property (@{
			'x'=$x;
			'y'=$y;
			'width'=$width;
			'height'=$height;
		})
	})
}

function GetTaskCoordinates($task, $origin, $taskTypeCount, $processed)
{
	$width = 100
	$height = 80
	$margin = 20
	$type = [int]$task.tasktype
	$count = $taskTypeCount
	$x = $origin.x + ($type * $width) + $margin
	$y = $origin.y + $margin

	return (@{'x'= $x; 'y'= $y; })
}

function ToDiagram($collaboration, $process)
{
	$customerShape = 
		New-Object -TypeName bpm.BPMNShape -Property (@{
			'id'=$collaboration.Participant.Id+'_di';
			'bpmnElement'=$collaboration.Participant.Id;
			'Bounds'= New-Object -TypeName bpm.Bounds -Property (@{
				'x'=370;
				'y'=270;
				'width'=830;
				'height'=260;
			})
		})
	
	$tasksWithInfo = 
		$process.Items |
		? { $_.GetType() -eq (new-object -typename bpm.tTask).GetType() } |
		Group-Object -Property tasktype |
		% -Begin {
			$info = @()
		} -Process { 
			$grouped = @{ 
				'tasks'= $_.Group; 
				'tasksTypeId' = $_.Name;
				'tasksCount' = $_.Count; }
			$info += $grouped
		} -End {
			$info
		}
	
	# name=1, count=2, group=task[], tasks=groupInfo[]
	$taskShapes = #
		$tasksWithInfo |
		% -Begin {
			$type = $_.Name; $numType = $_.Count;
		} -Process { 
			($_.Group) |
			ForEach-Object -Begin { 
				$processed = 1; $shapes = @(); 
			} -Process {
				$coord = GetTaskCoordinates $_ (@{'x'= 370; 'y'= 270; }) $numType $processed;
				$processed = $processed + 1;
				$shapes += ToShape $_.id $coord.x $coord.y 100 80;
			} -End { 
				$shapes }
		} -End {
			$shapes
		}

	$shapes = @(
		@($customerShape) +
		@($taskShapes)
	) |
	%{ $_ } #flatten

	$plane = New-Object -TypeName bpm.BPMNPlane -Property (@{
		'id'='BPMNPlane';
		'bpmnElement'=$collaboration.Id;
		'DiagramElement1'=$shapes;
	})

	$diagram = New-Object -TypeName bpm.BPMNDiagram -Property (@{
		'id'='BPMNDiagram';
		'BPMNPlane'=$plane
	})
	return $diagram
}

function Serialize($definitions)
{
	$serializer = New-Object -typeName System.Xml.Serialization.XmlSerializer($definitions.GetType(), @(
		(new-object -TypeName bpm.BPMNShape).GetType()
	))
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
	$ns.Add("bpmndi", "http://www.omg.org/spec/BPMN/20100524/DI");
	$ns.Add("dc", "http://www.omg.org/spec/DD/20100524/DC");
	$ns.Add("di", "http://www.omg.org/spec/DD/20100524/DI");
    $ns.Add("xsi", "http://www.w3.org/2001/XMLSchema-instance");
    
	$serializer.Serialize($writer, $definitions, $ns)
    
	$ms.Position = 0
	$streamReader = New-Object -TypeName System.IO.StreamReader($ms)
	$data = $streamReader.ReadToEnd()

	$ms.Close | Out-Null
	return $data
}

function CreateXml($customer)
{
	$collaboration = ToCollaboration($customer)
	$process = ToProcess($customer)
	$diagram = ToDiagram $collaboration $process

	$xml = New-Object -TypeName bpm.tDefinitions -Property (@{
	'id'='Definitions';
	'Items'= @(		
		$collaboration,
		$process);
	'BPMNDiagram'= @($diagram);
	})
	return $xml;
}

Write-Output (Serialize (CreateXml $customer)) |
		out-file -filePath (Join-Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) "bpm.xml") 
