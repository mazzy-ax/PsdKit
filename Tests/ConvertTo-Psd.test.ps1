
. ./About.ps1 ConvertTo-Psd

task Indent {
	# 2 spaces as 2
	($r = ConvertTo-Psd @{x=1} -Indent 2)
	Test-Hash $r 9a0cd32559172d5f6aa0897c77e72064

	# 3 spaces as string
	($r = ConvertTo-Psd @{x=1} -Indent '   ')
	Test-Hash $r 501a6d93880811af350d8dbb33c84c06

	# 4 spaces default
	($r = ConvertTo-Psd @{x=1})
	Test-Hash $r 75e606b3d43e410e849cde5b048860bb

	# 4 spaces as 4
	($r = ConvertTo-Psd @{x=1} -Indent 4)
	Test-Hash $r 75e606b3d43e410e849cde5b048860bb

	# tab as 1
	($r = ConvertTo-Psd @{x=1} -Indent 1)
	Test-Hash $r 838429fa71b915d95172f5d2798d15a8
}

task Mixed -If ($Version -ge 3) {
	$data = @(
		$null
		'bar1'
		42
		99d
		3.14
		$true
		$false
		[datetime]'2018-02-19'
		,@(1, "'bar'")
		[ordered]@{
			array = 1, 2, [ordered]@{p1=1; p2=2}
			table = [ordered]@{p1=1; p2=1,2}
			emptyArray = @()
			emptyTable = @{}
			"1'key'" = 42
			2 = 'int key'
			3L = 'long key'
		}
	)

	($r = $data | ConvertTo-Psd)
	Test-Hash $r 9b008c8dd6952bfa5bd30f09d7944155
}

task DateTime {
	$date = [datetime]'2018-02-19'

	($r = ConvertTo-Psd @{Date = [datetime]'2018-02-19'})
	Test-Hash $r ac8e2b066907a02e73d4f21ef726c3e2
	equals ((Invoke-Expression $r).Date) $date

	($r = ConvertTo-Psd @{Date = [datetime]636545952000000000})
	Test-Hash $r ac8e2b066907a02e73d4f21ef726c3e2
	equals ((Invoke-Expression $r).Date) $date
}

task PSCustomObject {
	$data = 1 | Select-Object name, array, object
	$data.name = 'bar'
	$data.array = 1, 2
	$data.object = 1 | Select-Object name, value
	$data.object.name = 'bar2'
	$data.object.value = 42
	($r = ConvertTo-Psd $data)
	Test-Hash $r a7e67885e0e41a8be8ef93d2a95223ec
}

#! In v2, Get-Date results in "not supported type Microsoft.PowerShell.Commands.DisplayHintType"
#! [DateTime]::Now is fine in all versions
task LoggingExample {
	# new log
    @{time = [DateTime]::Now; text = 'text1'} | ConvertTo-Psd | Set-Content z.psd1
    # append log
    @{time = [DateTime]::Now; text = 'text2'} | ConvertTo-Psd | Add-Content z.psd1
    @{time = [DateTime]::Now; text = 'text3'} | ConvertTo-Psd | Add-Content z.psd1

    # read log
    ($r = Import-Psd z.psd1)
    equals $r.Count 3
    equals $r[0].text text1
    equals $r[1].text text2
    equals $r[2].text text3

    Remove-Item z.psd1
}

task JsonToPsd -If ($Version -ge 5) {
	$json = ConvertTo-Json ([PSCustomObject]@{
		string = 'bar'
		number = 42
		array = 1, 2
	})

	($r = $json | ConvertFrom-Json | ConvertTo-Psd)
	Test-Hash $r f550e9ceb0df2caf8eddba1f50a1d64c
}

task SwitchParameter {
	$f = [switch]$false
	$t = [switch]$true
	($r = ConvertTo-Psd $f)
	equals $r '$false'
	($r = ConvertTo-Psd $t)
	equals $r '$true'
}

# Issue #1
task Enum {
	($r = [ConsoleColor]'Cyan' | ConvertTo-Psd)
	equals $r "'Cyan'"

	if ($Version -ge 5) {
		($r = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12' | ConvertTo-Psd)
		equals $r "'Ssl3, Tls, Tls11, Tls12'"
	}
}

# Issue #2
task GuidAndVersion {
	($r = [guid]'8b3ab2af-7c2f-401b-902c-1c06369bd5c2' | ConvertTo-Psd)
	equals $r "'8b3ab2af-7c2f-401b-902c-1c06369bd5c2'"

	($r = [version]'1.2.3' | ConvertTo-Psd)
	equals $r "'1.2.3'"
}

# In psd1, `[DBNull]::Value` is not allowed and `[DBNull] $null` is just $null.
# We do not have much choice, let's just write `$null` until it is a problem.
task DBNull {
	($r = [DBNull]::Value | ConvertTo-Psd)
	equals $r '$null'
}

#! found on PSGetModuleInfo.xml clixml to psd1
task Uri {
	($r = [uri]'bar' | ConvertTo-Psd)
	equals $r "'bar'"
}

#! found on PSGetModuleInfo.xml clixml to psd1
task IEnumerableBeforePSCustomObject {
	@{Tags = 'tag1', 'tag2'} | Export-Clixml z.clixml
	$r = Import-Clixml z.clixml

	#! fixed
	($r | ConvertTo-Psd)
	Test-Hash $r 9a63cc449e6068a2f7ec217bb4543eb2

	Remove-Item z.clixml
}

# Some data are IEnumerable but not IList or ICollection.
# It's unlikely that we have such cases on serialisation.
# But on object dumps everything is possible.
task IEnumerableInsteadOfICollection -If ($Version -ge 5) {
	$data = @{x = [IO.Directory]::EnumerateFiles($BuildRoot, 'ConvertTo-Psd.test.ps1')}
	($r = ConvertTo-Psd $data)
	$r = Invoke-Expression $r
	equals $r.x.GetType() ([object[]])
	equals $r.x.Count 1
	equals $r.x[0] $BuildFile
}

# Dump any objects with the parameter Depth, #4.
# NB 2 module warnings are not recorded by IB.
task Depth {
	# no Depth -> not supported
	($r = try {$Host | ConvertTo-Psd} catch {$_})
	assert ("$r" -like 'Not supported type *')

	# Depth 1 -> 1 level
	($r = $Host | ConvertTo-Psd -Depth 1)
	$r = Invoke-Expression $r
	equals $r.Name $Host.Name
	equals $r.Runspace ''''

	# Depth 2 -> 2 levels
	($r = $Host | ConvertTo-Psd -Depth 2)
	$r = Invoke-Expression $r
	equals ([guid]$r.Runspace.InstanceId) $Host.Runspace.InstanceId
	equals $r.Runspace.RunspaceStateInfo ''''
}

task BadKeyAndSurrogateItem {
	$data = @{
		[DateTime] '2018-01-01' = 1
		[DateTime] '2018-01-02' = 2
	}

	# normal mode, bad key
	($r = try {ConvertTo-Psd $data} catch {$_})
	equals "$r" "Not supported key type 'System.DateTime'."

	# dump mode, surrogate items
	($r = ConvertTo-Psd $data -Depth 2)
	Test-Hash $r 09663c9c7a0ef7d66a6163882c02aa94
}

# Convert data with script blocks.
task Blocks {
	$data = @{
		Id = 1
		Block = {42}
	}
	($r = ConvertTo-Psd $data)
	$r = & ([scriptblock]::Create($r))
	equals $r.Count 2
	equals $r.Id 1
	equals ($r.Block.GetType()) ([scriptblock])
	equals (& $r.Block) 42
}
