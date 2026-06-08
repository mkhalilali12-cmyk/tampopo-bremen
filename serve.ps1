# Tiny no-admin static server (raw TCP sockets). Serves files from this folder.
$port = 3000
$root = $PSScriptRoot

$mime = @{
  '.html' = 'text/html; charset=utf-8'
  '.png'  = 'image/png'
  '.jpg'  = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.svg'  = 'image/svg+xml'
  '.css'  = 'text/css; charset=utf-8'
  '.js'   = 'application/javascript; charset=utf-8'
  '.ico'  = 'image/x-icon'
  '.webp' = 'image/webp'
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $port)
$listener.Start()
Write-Host "Serving $root on http://0.0.0.0:$port  (Ctrl+C to stop)"

while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    $stream = $client.GetStream()

    # Read the request line/headers
    $buffer = New-Object byte[] 8192
    Start-Sleep -Milliseconds 15
    $reqText = ''
    if ($stream.DataAvailable) {
      $n = $stream.Read($buffer, 0, $buffer.Length)
      $reqText = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $n)
    }

    # Parse path from "GET /path HTTP/1.1"
    $path = '/'
    if ($reqText -match '^[A-Z]+\s+(\S+)\s') { $path = $matches[1] }
    $path = ($path -split '\?')[0]
    if ($path -eq '/' -or $path -eq '') { $path = '/index.html' }

    # Resolve safely inside root
    $rel = $path.TrimStart('/') -replace '/', '\'
    $rel = [System.Uri]::UnescapeDataString($rel)
    $full = Join-Path $root $rel

    if ((Test-Path $full -PathType Leaf) -and ($full.StartsWith($root))) {
      $ext = [System.IO.Path]::GetExtension($full).ToLower()
      $ctype = $mime[$ext]; if (-not $ctype) { $ctype = 'application/octet-stream' }
      $bodyBytes = [System.IO.File]::ReadAllBytes($full)
      $header =
        "HTTP/1.1 200 OK`r`n" +
        "Content-Type: $ctype`r`n" +
        "Content-Length: $($bodyBytes.Length)`r`n" +
        "Cache-Control: no-store`r`n" +
        "Connection: close`r`n`r`n"
    } else {
      $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes('404 Not Found')
      $header =
        "HTTP/1.1 404 Not Found`r`n" +
        "Content-Type: text/plain`r`n" +
        "Content-Length: $($bodyBytes.Length)`r`n" +
        "Connection: close`r`n`r`n"
    }

    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
    $stream.Write($headerBytes, 0, $headerBytes.Length)
    $stream.Write($bodyBytes, 0, $bodyBytes.Length)
    $stream.Flush()
  } catch {
  } finally {
    $client.Close()
  }
}
