# 导入 posh-git 模块
Import-Module posh-git -ErrorAction SilentlyContinue

# 导入 PSReadLine 模块
Import-Module PSReadLine -ErrorAction SilentlyContinue

# 设置 PSReadLine 选项（增强命令行体验）
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -EditMode Windows

# 初始化 oh-my-posh（新版方式）
$ohMyPoshCommand = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if ($ohMyPoshCommand) {
    $themeCandidates = @()
    if ($env:POSH_THEMES_PATH) {
        $themeCandidates += Join-Path $env:POSH_THEMES_PATH 'robbyrussell.omp.json'
    }
    $themeCandidates += Join-Path $env:LOCALAPPDATA 'Programs\oh-my-posh\themes\robbyrussell.omp.json'

    $resolvedTheme = $themeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($resolvedTheme) {
        oh-my-posh init pwsh --config $resolvedTheme | Invoke-Expression
    }
    else {
        oh-my-posh init pwsh | Invoke-Expression
    }
}
else {
    Write-Warning '未检测到 oh-my-posh，可通过 winget install JanDeDobbeleer.OhMyPosh -s winget 进行安装。'
}

# 启动 lemonade server（若未运行）
$lemonadeProcess = Get-Process -Name lemonade -ErrorAction SilentlyContinue
if (-not $lemonadeProcess) {
    $existingLemonadeJob = Get-Job -Name 'lemonade-server' -ErrorAction SilentlyContinue
    if (-not $existingLemonadeJob) {
        Start-Job -Name 'lemonade-server' -ScriptBlock { lemonade server } | Out-Null
    }
}

# 设置vim的别名为vi
Set-Alias -Name vi -Value vim

function ya {
    # 创建临时文件
    $tempFile = New-TemporaryFile
    
    # 启动 yazi 并传递临时文件路径
    yazi --cwd-file="$($tempFile.FullName)"
    
    # 检查临时文件是否存在且不为空
    if (Test-Path $tempFile.FullName) {
        $newDir = Get-Content $tempFile.FullName -Raw
        # 移除可能的换行符
        $newDir = $newDir.Trim()
        
        if ($newDir -and (Test-Path $newDir) -and ($newDir -ne $PWD.Path)) {
            Set-Location $newDir
        }
        Remove-Item $tempFile.FullName
    }
}

# 修复lua乱码问题

# function lu {
#     param(
#         [Parameter(Mandatory=$true)]
#         [string]$Script,
#         [string[]]$Args
#     )
#
#     # 保存原始编码
#     $oldOutput = [Console]::OutputEncoding
#     $oldError = [Console]::InputEncoding
#
#     # 设置为UTF-8
#     [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
#     [Console]::InputEncoding = [System.Text.Encoding]::UTF8
#
#     try {
#         # 运行Lua并转换输出
#         if ($Args.Count -gt 0) {
#             lua $Script @Args
#         } else {
#             lua $Script
#         }
#     } finally {
#         # 恢复原始编码
#         [Console]::OutputEncoding = $oldOutput
#         [Console]::InputEncoding = $oldError
#     }
# }

# 1. 定义代理地址变量
$proxyAddr = "http://127.0.0.1:8118"
$noProxyAddr = "localhost,127.0.0.1,api.deepseek.com"

# 2. 定义开启代理的函数
function Set-Proxy {
    $env:HTTP_PROXY  = $proxyAddr
    $env:HTTPS_PROXY = $proxyAddr
    $env:http_proxy  = $proxyAddr
    $env:https_proxy = $proxyAddr

    # 设置 NO_PROXY
    $env:NO_PROXY    = $noProxyAddr
    $env:no_proxy    = $noProxyAddr

    Write-Host "--- 🚀 代理已开启: $proxyAddr ---" -ForegroundColor Cyan
    Write-Host "--- 🌐 绕过代理列表: $noProxyAddr ---" -ForegroundColor DarkGray
}

# 3. 定义取消代理的函数
function Unset-Proxy {
    $env:HTTP_PROXY  = $null
    $env:HTTPS_PROXY = $null
    $env:http_proxy  = $null
    $env:https_proxy = $null

    # 清除 NO_PROXY
    $env:NO_PROXY    = $null
    $env:no_proxy    = $null

    Write-Host "--- 🛑 代理已关闭 ---" -ForegroundColor Yellow
}

# 4. 终端启动时执行
Set-Proxy

# 5. 显示提示词
Write-Host "💡 提示: 输入 " -NoNewline
Write-Host "Unset-Proxy" -ForegroundColor Yellow -NoNewline
Write-Host " 可取消代理，输入 " -NoNewline
Write-Host "Set-Proxy" -ForegroundColor Cyan -NoNewline
Write-Host " 重新开启。"

# 设置UTF-8编码
# $OutputEncoding = [System.Text.UTF8Encoding]::new()
# [Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
# [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# 配置 zoxide
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# 配置 fzf

## Ctrl+R: 搜索命令历史
function Invoke-FzfHistory {
    $command = (Get-Content (Get-PSReadlineOption).HistorySavePath | fzf)
    if ($command) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($command)
    }
}

## Ctrl+T: 搜索文件并插入路径
function Invoke-FzfFile {
    $file = fzf
    if ($file) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($file)
    }
}

Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock { Invoke-FzfHistory }
Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock { Invoke-FzfFile }

## ** + Tab: 模糊补全（手动实现）
function Invoke-FzfTabCompletion {
    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    
    # 检查光标前是否有 **
    if ($line.Substring(0, $cursor) -match '\*\*$') {
        # 获取 ** 前的命令部分
        $prefix = $line.Substring(0, $cursor - 2)
        
        # 打开 fzf 选择文件
        $selected = fzf
        if ($selected) {
            # 替换 ** 为选中的路径
            $newLine = $prefix + $selected + $line.Substring($cursor)
            [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, $newLine)
            # 将光标移到替换后的末尾
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($prefix.Length + $selected.Length)
        }
    } else {
        # 没有 **，使用默认补全
        [Microsoft.PowerShell.PSConsoleReadLine]::TabCompleteNext()
    }
}

# 绑定 Tab 键
Set-PSReadLineKeyHandler -Key Tab -ScriptBlock { Invoke-FzfTabCompletion }
