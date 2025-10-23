param(
	[int]$BackendPort,
	[string]$FrontendOrigin
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Net.Http

$rootDir = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $rootDir 'backend/logs'
$debugLog = Join-Path $logDir 'connectivity-debug.log'
$resultFile = Join-Path $rootDir 'CONNECTIVITY-RESULT.json'

if (-not $BackendPort) {
	if ($env:BACKEND_PORT -as [int]) {
		$BackendPort = [int]$env:BACKEND_PORT
	}
	else {
		$BackendPort = 8000
	}
}

if (-not $FrontendOrigin) {
	$FrontendOrigin = if ($env:FRONTEND_ORIGIN) { $env:FRONTEND_ORIGIN } else { 'http://localhost:5173' }
}

New-Item -ItemType Directory -Path $logDir -Force | Out-Null
Set-Content -Path $debugLog -Value '' -Encoding utf8

function Write-DebugLog {
	param([string]$Message)
	$entry = "[{0}] {1}" -f (Get-Date).ToString('s'), $Message
	Add-Content -Path $debugLog -Value $entry -Encoding utf8
	Write-Host $entry
}

$result = [ordered]@{
	timestamp         = (Get-Date).ToUniversalTime().ToString('o')
	backend_health    = @{ status = 'fail'; details = 'backend not checked'; raw = '' }
	backend_checknews = @{ status = 'fail'; details = 'not run'; response = '' }
	cors              = @{ status = 'fail'; details = 'not checked'; headers = ''; allowed_config = '' }
	frontend_env      = @{ status = 'fail'; details = 'not checked'; detected_base = '' }
	e2e               = @{ status = 'fail'; details = 'not run'; response = '' }
	prereqs           = @{ node = 'missing'; npm = 'missing'; python = 'missing'; uvicorn = 'missing' }
	recommendations   = @()
	status            = 'fail'
}

function Add-Recommendation {
	param([string]$Text)
	if ([string]::IsNullOrWhiteSpace($Text)) { return }
	if (-not ($result.recommendations -contains $Text)) {
		$result.recommendations += $Text
	}
}

function Get-VersionOutput {
	param(
		[string]$Command,
		[string[]]$ArgumentList
	)
	$tempOut = [System.IO.Path]::GetTempFileName()
	$tempErr = [System.IO.Path]::GetTempFileName()
	try {
		$process = Start-Process -FilePath $Command -ArgumentList $ArgumentList -NoNewWindow -RedirectStandardOutput $tempOut -RedirectStandardError $tempErr -PassThru
		$process.WaitForExit()
		$output = ''
		if (Test-Path $tempOut) {
			$output = Get-Content -Path $tempOut -Raw
		}
		if (-not $output -and (Test-Path $tempErr)) {
			$output = Get-Content -Path $tempErr -Raw
		}
		return $output.Trim()
	}
	catch {
		return ''
	}
	finally {
		Remove-Item $tempOut -ErrorAction SilentlyContinue
		Remove-Item $tempErr -ErrorAction SilentlyContinue
	}
}

function Register-Prerequisite {
	param(
		[string]$Label,
		[string]$Command,
		[string[]]$VersionArgs = @('--version'),
		[string]$MissingMessage,
		[switch]$MuteRecommendation
	)
	$cmd = Get-Command -Name $Command -ErrorAction SilentlyContinue
	if ($cmd) {
		$version = Get-VersionOutput -Command $cmd.Source -ArgumentList $VersionArgs
		if (-not $version) { $version = 'detected' }
		$result.prereqs[$Label] = $version
		Write-DebugLog ("Detected {0}: {1}" -f $Label, $version)
		return @{ Found = $true; Path = $cmd.Source }
	}

	Write-DebugLog ("Missing prerequisite: {0} ({1})" -f $Label, $Command)
	if (-not $MuteRecommendation -and $MissingMessage) {
		Add-Recommendation $MissingMessage
	}
	return @{ Found = $false; Path = $null }
}

Register-Prerequisite -Label 'node' -Command 'node' -VersionArgs @('--version') -MissingMessage 'Install Node.js and ensure node is available in PATH.' | Out-Null
Register-Prerequisite -Label 'npm' -Command 'npm' -VersionArgs @('--version') -MissingMessage 'Install npm (bundled with Node.js) and ensure it is available in PATH.' | Out-Null

$pythonInfo = $null
foreach ($candidate in @('python3', 'python', 'py')) {
	$cmd = Get-Command -Name $candidate -ErrorAction SilentlyContinue
	if (-not $cmd) {
		continue
	}
	$versionOutput = Get-VersionOutput -Command $cmd.Source -ArgumentList @('-c', 'import platform; print(platform.python_version())')
	if ($versionOutput -match '^[0-9]+\.[0-9]+(\.[0-9]+)?') {
		$pythonInfo = @{ Path = $cmd.Source; Version = $versionOutput; Name = $candidate }
		$result.prereqs.python = $versionOutput
		Write-DebugLog ("Detected python via {0}: {1}" -f $candidate, $versionOutput)
		break
	}
	else {
		$displayOutput = if ($versionOutput) { $versionOutput } else { '<empty>' }
		Write-DebugLog ("Candidate {0} did not return a valid python version: {1}" -f $candidate, $displayOutput)
	}
}

if (-not $pythonInfo) {
	Add-Recommendation 'Install Python 3.10+ and ensure it is available in PATH.'
	Add-Recommendation "Install uvicorn via 'pip install uvicorn[standard]' to run the backend server."
	Write-DebugLog 'Python unavailable; skipping Python-powered checks.'
}
else {
	Write-DebugLog ("Using python binary at {0}" -f $pythonInfo.Path)
	$uvicornInfo = Register-Prerequisite -Label 'uvicorn' -Command 'uvicorn' -VersionArgs @('--version') -MissingMessage "Install uvicorn via 'pip install uvicorn[standard]' to run the backend server."
	if (-not $uvicornInfo.Found) {
		$result.prereqs.uvicorn = 'missing'
	}
}

# include typical loopback aliases; skip 0.0.0.0 because Windows HttpClient rejects it
$backendHosts = @('127.0.0.1', 'localhost')
$checkPayload = '{"text":"connectivity test"}'
$httpClient = [System.Net.Http.HttpClient]::new()
$httpClient.Timeout = [TimeSpan]::FromSeconds(8)

try {
	foreach ($backendHost in $backendHosts) {
		$healthUrl = [string]::Format("http://{0}:{1}/health", $backendHost, $BackendPort)
		Write-DebugLog ("Checking backend health at {0}" -f $healthUrl)
		try {
			$response = $httpClient.GetAsync($healthUrl).GetAwaiter().GetResult()
			$body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
			if ($response.IsSuccessStatusCode -and $body) {
				try {
					$json = $body | ConvertFrom-Json
					if ($json.status -eq 'ok') {
						$result.backend_health.status = 'pass'
						$result.backend_health.details = ("{0} responded with status ok" -f $healthUrl)
						$result.backend_health.raw = ($json | ConvertTo-Json -Depth 4)
						break
					}
				}
				catch {
					Write-DebugLog ("Health response parsing failed: {0}" -f $_.Exception.Message)
				}
			}
			else {
				Write-DebugLog ("Health request to {0} returned HTTP {1}" -f $healthUrl, [int]$response.StatusCode)
			}
		}
		catch {
			Write-DebugLog ("Health check failed for {0}: {1}" -f $healthUrl, $_.Exception.Message)
			if ($result.backend_health.status -ne 'pass') {
				$result.backend_health.details = ("{0} failed: {1}" -f $healthUrl, $_.Exception.Message)
			}
		}
	}
	foreach ($backendHost in $backendHosts) {
		$checkUrl = [string]::Format("http://{0}:{1}/check-news", $backendHost, $BackendPort)
		Write-DebugLog ("Posting payload to {0}" -f $checkUrl)
		try {
			$content = New-Object System.Net.Http.StringContent($checkPayload, [System.Text.Encoding]::UTF8, 'application/json')
			$response = $httpClient.PostAsync($checkUrl, $content).GetAwaiter().GetResult()
			$body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
			if ($response.IsSuccessStatusCode -and $body) {
				try {
					$json = $body | ConvertFrom-Json
					if ($json.verdict -and $null -ne $json.confidence) {
						$result.backend_checknews.status = 'pass'
						$result.backend_checknews.details = ("{0} returned verdict" -f $checkUrl)
						$result.backend_checknews.response = ($json | ConvertTo-Json -Depth 6)
						break
					}
				}
				catch {
					Write-DebugLog ("Check-news response parsing failed: {0}" -f $_.Exception.Message)
				}
			}
			else {
				$result.backend_checknews.details = ("{0} returned HTTP {1}" -f $checkUrl, [int]$response.StatusCode)
			}
		}
		catch {
			Write-DebugLog ("Check-news failed for {0}: {1}" -f $checkUrl, $_.Exception.Message)
			$result.backend_checknews.details = ("{0} failed: {1}" -f $checkUrl, $_.Exception.Message)
		}
	}

	if ($pythonInfo) {
		$mainPath = Join-Path $rootDir 'backend/app/main.py'
		if (Test-Path $mainPath) {
			try {
				$script = 'import pathlib, re, sys\ntext = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")\nmatch = re.search(r"allow_origins\\s*=\\s*\\[(.*?)\\]", text, re.DOTALL)\nprint(" ".join(match.group(1).split()) if match else "")'
				$allowed = & $pythonInfo.Path '-c' $script $mainPath
				$result.cors.allowed_config = $allowed.Trim()
			}
			catch {
				Write-DebugLog ("Failed to inspect FastAPI CORS configuration: {0}" -f $_.Exception.Message)
			}
		}
	}

	foreach ($backendHost in $backendHosts) {
		$corsUrl = [string]::Format("http://{0}:{1}/check-news", $backendHost, $BackendPort)
		Write-DebugLog ("Testing CORS preflight for {0}" -f $corsUrl)
		try {
			$request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Options, $corsUrl)
			$request.Headers.Add('Origin', $FrontendOrigin)
			$request.Headers.Add('Access-Control-Request-Method', 'POST')
			$response = $httpClient.SendAsync($request).GetAwaiter().GetResult()
			$headerLines = @()
			foreach ($header in $response.Headers) {
				$headerLines += "{0}: {1}" -f $header.Key, (($header.Value) -join ', ')
			}
			$result.cors.headers = ($headerLines -join "`n")
			if ($response.Headers.Contains('Access-Control-Allow-Origin')) {
				$origins = $response.Headers.GetValues('Access-Control-Allow-Origin')
				if ($origins -contains '*' -or $origins -contains $FrontendOrigin) {
					$result.cors.status = 'pass'
					$result.cors.details = ("Preflight succeeded for {0}" -f $FrontendOrigin)
					break
				}
			}
			$result.cors.details = ("Preflight missing Access-Control-Allow-Origin for {0}" -f $FrontendOrigin)
		}
		catch {
			Write-DebugLog ("CORS preflight failed for {0}: {1}" -f $corsUrl, $_.Exception.Message)
			$result.cors.details = ("Preflight failed: {0}" -f $_.Exception.Message)
		}
	}

	foreach ($backendHost in $backendHosts) {
		$url = [string]::Format("http://{0}:{1}/check-news", $backendHost, $BackendPort)
		Write-DebugLog ("Performing browser-style request to {0}" -f $url)
		try {
			$request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $url)
			$request.Headers.Add('Origin', $FrontendOrigin)
			$request.Content = New-Object System.Net.Http.StringContent($checkPayload, [System.Text.Encoding]::UTF8, 'application/json')
			$response = $httpClient.SendAsync($request).GetAwaiter().GetResult()
			$body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
			$result.e2e.response = $body
			if ($response.IsSuccessStatusCode -and $body) {
				try {
					$json = $body | ConvertFrom-Json
					if ($json.verdict) {
						$result.e2e.status = 'pass'
						$result.e2e.details = ("Browser-style request succeeded at {0}" -f $url)
						break
					}
				}
				catch {
					Write-DebugLog ("Failed to parse JSON response from {0}: {1}" -f $url, $_.Exception.Message)
					$result.e2e.details = 'Received non-JSON response.'
				}
			}
			else {
				$result.e2e.details = ("HTTP {0} from {1}" -f ([int]$response.StatusCode), $url)
			}
		}
		catch {
			Write-DebugLog ("E2E request failed for {0}: {1}" -f $url, $_.Exception.Message)
			$result.e2e.details = ("Request failed: {0}" -f $_.Exception.Message)
		}
	}
}
finally {
	$httpClient.Dispose()
}

if ($result.backend_health.status -ne 'pass') {
	Add-Recommendation "Ensure backend server is running: cd backend && uvicorn app.main:app --reload --port $BackendPort"
}

if ($result.backend_checknews.status -ne 'pass') {
	Add-Recommendation 'Investigate backend /check-news endpoint; verify services and dependencies.'
}

if ($result.cors.status -ne 'pass') {
	Add-Recommendation "Update FastAPI CORSMiddleware allow_origins to include $FrontendOrigin."
}

$envFiles = @(
	Join-Path -Path $rootDir -ChildPath 'frontend/.env'
	Join-Path -Path $rootDir -ChildPath 'frontend/.env.local'
	Join-Path -Path $rootDir -ChildPath 'frontend/.env.development'
)

$detectedBase = $null
foreach ($file in $envFiles) {
	if (Test-Path $file) {
		$match = Select-String -Path $file -Pattern '^VITE_API_BASE_URL=(.+)$' -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($match) {
			$detectedBase = $match.Matches[0].Groups[1].Value.Trim().TrimEnd('/')
			Write-DebugLog ("Detected VITE_API_BASE_URL={0} from {1}" -f $detectedBase, $file)
			break
		}
	}
}

if (-not $detectedBase) {
	$apiFile = Join-Path $rootDir 'frontend/src/services/api.js'
	if (Test-Path $apiFile) {
		$match = Select-String -Path $apiFile -Pattern 'http://[^"'' ]+' -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($match) {
			$detectedBase = $match.Matches[0].Value.TrimEnd('/')
			Write-DebugLog ("Detected base URL from api.js: {0}" -f $detectedBase)
		}
	}
}

if (-not $detectedBase) {
	$detectedBase = [string]::Format("http://localhost:{0}", $BackendPort)
	$result.frontend_env.status = 'warn'
	$result.frontend_env.details = ("No VITE_API_BASE_URL set; defaulting to {0}" -f $detectedBase)
}
else {
	$result.frontend_env.details = ("Detected API base {0}" -f $detectedBase)
	$expectedLocalhost = [string]::Format("http://localhost:{0}", $BackendPort)
	$expectedLoopback = [string]::Format("http://127.0.0.1:{0}", $BackendPort)
	if ($detectedBase.StartsWith($expectedLocalhost, [System.StringComparison]::OrdinalIgnoreCase) -or $detectedBase.StartsWith($expectedLoopback, [System.StringComparison]::OrdinalIgnoreCase)) {
		$result.frontend_env.status = 'pass'
	}
	else {
		$result.frontend_env.status = 'warn'
		Add-Recommendation ([string]::Format("Set VITE_API_BASE_URL={0} in frontend/.env and restart Vite server.", $expectedLocalhost))
	}
}

$result.frontend_env.detected_base = $detectedBase

if ($result.e2e.status -ne 'pass') {
	Add-Recommendation 'Run npm run dev and use runConnectivityCheck() helper in the browser to inspect errors.'
}

Write-DebugLog ("Backend health details recorded: {0}" -f $result.backend_health.details)

if ($result.backend_health.status -eq 'pass' -and $result.backend_checknews.status -eq 'pass' -and $result.cors.status -eq 'pass' -and $result.e2e.status -eq 'pass') {
	$result.status = 'pass'
}
else {
	$result.status = 'fail'
}

$json = $result | ConvertTo-Json -Depth 8
Set-Content -Path $resultFile -Value ($json + "`n") -Encoding utf8

Write-DebugLog "Connectivity verification completed with status $($result.status)"

if ($result.status -eq 'pass') {
	exit 0
}
else {
	exit 1
}