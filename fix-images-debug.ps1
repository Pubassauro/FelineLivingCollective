# Script para baixar imagens remotas e corrigir capas (DEBUG VERSION)
# Autor: Antigravity

$postsDir = "content/posts"
$imgDir = "static/images/medium"

# Cria diretório de imagens se não existir
if (-not (Test-Path $imgDir)) {
    New-Item -ItemType Directory -Path $imgDir | Out-Null
}

$files = Get-ChildItem $postsDir -Filter "*.md"

foreach ($file in $files) {
    Write-Host "Processando $($file.Name)..." -ForegroundColor Cyan
    $content = Get-Content $file.FullName -Raw
    $newContent = $content
    $firstImage = $null

    # Regex ajustada para capturar URLs dentro de shortcodes {{< img src="..." >}}
    # Captura tudo entre aspas após src=
    $pattern = 'src="([^"]+)"'
    $matches = [regex]::Matches($content, $pattern)

    Write-Host "  Encontradas $($matches.Count) imagens." -ForegroundColor Yellow

    foreach ($match in $matches) {
        $url = $match.Groups[1].Value
        
        # Ignorar se já for local (começa com /)
        if ($url.StartsWith("/")) {
            Write-Host "  Ignorando local: $url"
            continue
        }

        Write-Host "  Processando URL: $url"

        # Gerar nome de arquivo local
        # Usar hash MD5 da URL para garantir nome único e curto
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $hash = [BitConverter]::ToString($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($url))).Replace("-", "")
        $extension = ".jpg"
        if ($url -match "\.png") { $extension = ".png" }
        $filename = "$hash$extension"
        
        $localPath = Join-Path $imgDir $filename
        $publicPath = "/images/medium/$filename"

        # Baixar imagem se não existir
        if (-not (Test-Path $localPath)) {
            Write-Host "  Baixando para: $filename"
            
            # Usar Start-Process para garantir execução correta do curl
            $process = Start-Process -FilePath "curl.exe" -ArgumentList "-L", "-A", "Mozilla/5.0", "-o", "`"$localPath`"", "`"$url`"" -Wait -PassThru -NoNewWindow
            
            if (-not (Test-Path $localPath)) { 
                Write-Host "  ❌ Falha: Arquivo não criado em $localPath" -ForegroundColor Red
                continue 
            }
        }
        else {
            Write-Host "  Arquivo já existe: $filename"
        }

        # Substituir URL no conteúdo
        # Escape special characters in URL for regex replacement
        $escapedUrl = [regex]::Escape($url)
        $newContent = $newContent -replace $escapedUrl, $publicPath

        # Guardar a primeira imagem encontrada para ser a capa
        if (-not $firstImage) {
            $firstImage = $publicPath
        }
    }

    # Atualizar capa (frontmatter image:) se tivermos encontrado uma imagem
    if ($firstImage) {
        # Regex para substituir image: "..."
        $newContent = $newContent -replace 'image: ".*?"', "image: `"$firstImage`""
        Write-Host "  Capa atualizada para: $firstImage" -ForegroundColor Green
    }

    # Salvar arquivo se houve alterações
    if ($content -ne $newContent) {
        Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8
        Write-Host "  ✅ Arquivo atualizado!" -ForegroundColor Green
    }
    else {
        Write-Host "  Nenhuma alteração necessária." -ForegroundColor Gray
    }
}
