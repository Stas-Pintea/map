param(
  [int]$StartPort = 5500,
  [int]$MaxTries = 50
)

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

function Find-FreePort {
  param([int]$StartPort, [int]$MaxTries)

  for ($i = 0; $i -lt $MaxTries; $i++) {
    $port = $StartPort + $i
    $listener = $null
    try {
      $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
      $listener.Start()
      return @{ Port = $port; Listener = $listener }
    } catch {
      if ($listener) {
        $listener.Stop()
      }
    }
  }

  throw "No free port found in range $StartPort..$($StartPort + $MaxTries - 1)."
}

function Get-ContentType {
  param([string]$Path)

  switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
    ".html" { "text/html; charset=utf-8" }
    ".css" { "text/css; charset=utf-8" }
    ".js" { "application/javascript; charset=utf-8" }
    ".json" { "application/json; charset=utf-8" }
    ".png" { "image/png" }
    ".jpg" { "image/jpeg" }
    ".jpeg" { "image/jpeg" }
    ".svg" { "image/svg+xml" }
    ".ico" { "image/x-icon" }
    default { "application/octet-stream" }
  }
}

function Send-Response {
  param(
    [System.Net.Sockets.NetworkStream]$Stream,
    [int]$StatusCode,
    [string]$StatusText,
    [byte[]]$Body,
    [string]$ContentType = "text/plain; charset=utf-8"
  )

  $headers = "HTTP/1.1 $StatusCode $StatusText`r`nContent-Type: $ContentType`r`nContent-Length: $($Body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
  $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headers)
  $Stream.Write($headerBytes, 0, $headerBytes.Length)
  if ($Body.Length -gt 0) {
    $Stream.Write($Body, 0, $Body.Length)
  }
}

function Resolve-RequestPath {
  param([string]$UrlPath)

  $cleanPath = ($UrlPath -split "\?")[0]
  if ([string]::IsNullOrWhiteSpace($cleanPath) -or $cleanPath -eq "/") {
    $cleanPath = "/index.html"
  }

  $relativePath = [System.Uri]::UnescapeDataString($cleanPath).TrimStart("/")
  $candidate = Join-Path $Root $relativePath
  $resolved = Resolve-Path $candidate -ErrorAction SilentlyContinue
  if (-not $resolved) {
    return $null
  }

  $rootFullPath = [System.IO.Path]::GetFullPath($Root).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  ) + [System.IO.Path]::DirectorySeparatorChar
  $fileFullPath = [System.IO.Path]::GetFullPath($resolved.Path)
  if (-not $fileFullPath.StartsWith($rootFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $null
  }

  return $fileFullPath
}

$server = Find-FreePort -StartPort $StartPort -MaxTries $MaxTries
$port = $server.Port
$listener = $server.Listener
$url = "http://localhost:$port/index.html"

Write-Host "[INFO] Starting local server on port $port"
Write-Host "[INFO] Open $url"
Start-Process $url

try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
      $requestLine = $reader.ReadLine()
      do {
        $headerLine = $reader.ReadLine()
      } while ($null -ne $headerLine -and $headerLine -ne "")

      if (-not $requestLine) {
        Send-Response -Stream $stream -StatusCode 400 -StatusText "Bad Request" -Body ([System.Text.Encoding]::UTF8.GetBytes("Bad Request"))
        continue
      }

      $parts = $requestLine.Split(" ")
      if ($parts.Length -lt 2 -or $parts[0] -ne "GET") {
        Send-Response -Stream $stream -StatusCode 405 -StatusText "Method Not Allowed" -Body ([System.Text.Encoding]::UTF8.GetBytes("Method Not Allowed"))
        continue
      }

      $filePath = Resolve-RequestPath -UrlPath $parts[1]
      if (-not $filePath -or -not [System.IO.File]::Exists($filePath)) {
        Send-Response -Stream $stream -StatusCode 404 -StatusText "Not Found" -Body ([System.Text.Encoding]::UTF8.GetBytes("Not Found"))
        continue
      }

      $body = [System.IO.File]::ReadAllBytes($filePath)
      Send-Response -Stream $stream -StatusCode 200 -StatusText "OK" -Body $body -ContentType (Get-ContentType -Path $filePath)
    } catch {
      $body = [System.Text.Encoding]::UTF8.GetBytes("Server Error")
      Send-Response -Stream $stream -StatusCode 500 -StatusText "Internal Server Error" -Body $body
    } finally {
      $client.Close()
    }
  }
} finally {
  $listener.Stop()
}
