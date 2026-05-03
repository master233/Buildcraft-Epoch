$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

$mimeTypes = @{
    '.html' = 'text/html; charset=utf-8'
    '.js'   = 'application/javascript'
    '.wasm' = 'application/wasm'
    '.pck'  = 'application/octet-stream'
    '.png'  = 'image/png'
    '.ico'  = 'image/x-icon'
    '.css'  = 'text/css'
    '.json' = 'application/json'
    '.svg'  = 'image/svg+xml'
}

function Find-FreePort {
    param([int]$StartPort = 8089)
    $port = $StartPort
    while ($port -le 65535) {
        $test = New-Object System.Net.HttpListener
        $test.Prefixes.Add("http://127.0.0.1:${port}/")
        try {
            $test.Start()
            $test.Stop()
            return $port
        } catch {
            $port++
        } finally {
            $test.Close()
        }
    }
    return -1
}

$port = Find-FreePort -StartPort 8089
if ($port -eq -1) {
    Write-Host ""
    Write-Host "ERROR: No available port found (tried 8089-65535)." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:${port}/")

try {
    $listener.Start()
} catch {
    Write-Host ""
    Write-Host "ERROR: Failed to start server on port $port." -ForegroundColor Red
    Write-Host "Try running this script as Administrator." -ForegroundColor Yellow
    Write-Host "Detail: $_" -ForegroundColor Gray
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Server started: http://127.0.0.1:${port}" -ForegroundColor Green
Write-Host "Do not close this window" -ForegroundColor Yellow
Write-Host ""

Start-Sleep -Milliseconds 500
Start-Process "http://127.0.0.1:${port}"

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $path = $ctx.Request.Url.LocalPath
        if ($path -eq '/') { $path = '/index.html' }

        $filePath = Join-Path $root $path.TrimStart('/')
        $resp = $ctx.Response

        try {
            if (Test-Path $filePath) {
                $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                if ($mimeTypes.ContainsKey($ext)) {
                    $resp.ContentType = $mimeTypes[$ext]
                } else {
                    $resp.ContentType = 'application/octet-stream'
                }
                $resp.Headers.Add('Cross-Origin-Opener-Policy', 'same-origin')
                $resp.Headers.Add('Cross-Origin-Embedder-Policy', 'require-corp')

                $bytes = [System.IO.File]::ReadAllBytes($filePath)
                $resp.ContentLength64 = $bytes.Length
                $resp.OutputStream.Write($bytes, 0, $bytes.Length)
                $resp.OutputStream.Flush()
            } else {
                $resp.StatusCode = 404
                Write-Host "404: $path" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "Error serving ${path}: $_" -ForegroundColor Red
            try { $resp.StatusCode = 500 } catch {}
        }
        $resp.Close()
    }
} finally {
    $listener.Stop()
}
