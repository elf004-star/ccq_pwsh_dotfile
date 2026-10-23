# PowerShell 配置

个人 PowerShell dotfiles，在 Windows PowerShell 5.1 与 PowerShell 7 启动时加载提示符、命令行增强和代理设置。

## 文件说明

| 文件 | 说明 |
| --- | --- |
| `Microsoft.PowerShell_profile.ps1` | 主配置，启动 shell 时自动加载 |
| `powershell.config.json` | 将执行策略设为 `RemoteSigned`，仅 PowerShell 7 读取，Windows PowerShell 5.1 不支持 |
| `总结.md` | 一次配置修复的记录 |

## 配置内容

### 提示符与命令行增强

- **oh-my-posh**：使用 `robbyrussell` 主题。优先从 `$env:POSH_THEMES_PATH` 查找，找不到时回退到 `%LOCALAPPDATA%\Programs\oh-my-posh\themes`，主题缺失则用默认配置。
- **posh-git**：在提示符中显示 git 状态。
- **PSReadLine**：`Windows` 编辑模式，历史命令预测。Windows PowerShell 5.1 自带的 PSReadLine 2.0 没有 `PredictionSource` 参数，脚本会自动检测并跳过该设置。
- **zoxide**：`z` 快速目录跳转。
- **fzf**：
  - `Ctrl+R` 从历史命令中选择并插入；
  - `Ctrl+T` 选择文件并插入路径；
  - 输入 `**` 后按 `Tab` 模糊选文件，其他情况保持默认补全。
- **UTF-8**：编码设置相关代码位于脚本末尾，当前处于注释状态。

### 代理

终端启动时会自动执行 `Set-Proxy`，代理地址和绕过列表写在脚本的「代理配置」一节：

```powershell
$proxyAddr   = "http://127.0.0.1:18118"
$noProxyAddr = "localhost,127.0.0.1,api.deepseek.com,dashscope.aliyuncs.com"
```

修改这两行即可更换代理。`Set-Proxy` 会同时设置大写和小写的 `HTTP_PROXY`、`HTTPS_PROXY`、`ALL_PROXY`、`NO_PROXY`，并设置 `NODE_USE_ENV_PROXY=1`。

| 命令 | 作用 |
| --- | --- |
| `Set-Proxy` | 开启代理 |
| `Unset-Proxy` | 关闭代理 |
| `Get-ProxyStatus` | 查看当前代理相关环境变量 |

### 别名与函数

| 名称 | 作用 |
| --- | --- |
| `vi` | 指向 `vim` |
| `ya` | 用 yazi 浏览文件，退出后把当前目录切换到 yazi 中所在的目录 |
| `lemonade` 后台任务 | 启动终端时若 `lemonade` 进程不存在，则用 `Start-Job` 启动 `lemonade server` |

### 依赖

| 工具 | 用途 | 缺失时的表现 |
| --- | --- | --- |
| oh-my-posh | 提示符主题 | 打印安装提示，其余配置正常 |
| posh-git | git 状态提示 | 静默跳过 |
| PSReadLine | 行编辑、历史预测 | 静默跳过 |
| zoxide | `z` 跳转 | 启动时报错，其余配置正常 |
| fzf | `Ctrl+R`、`Ctrl+T`、`**`+`Tab` | 对应快捷键不可用 |
| yazi | `ya` 函数 | `ya` 不可用 |
| vim | `vi` 别名 | `vi` 不可用 |
| lemonade | 本地推理服务 | 后台任务启动后立即失败 |

安装 oh-my-posh：

```powershell
winget install JanDeDobbeleer.OhMyPosh -s winget
```

若执行脚本被拦截，先放开当前用户的执行策略：

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## 部署：软链接到 WindowsPowerShell

Windows PowerShell 5.1 只读取固定路径的用户配置文件：

```
%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
```

把仓库中的文件软链接到该位置，之后修改仓库里的文件即会直接生效，无需复制。

> **前提**：创建软链接需要以管理员身份运行 PowerShell，或开启 Windows 开发者模式（设置 → 更新和安全 → 开发者选项 → 开发人员模式）。否则会报「权限不足」。
>
> 下面的 `$repo` 默认指向 `$HOME\Documents\PowerShell`，请按仓库实际位置修改。

```powershell
# 仓库位置
$repo = "$HOME\Documents\PowerShell"

# Windows PowerShell 5.1 的配置目录
$linkDir = "$HOME\Documents\WindowsPowerShell"
$link    = Join-Path $linkDir 'Microsoft.PowerShell_profile.ps1'

# 目录不存在则创建
New-Item -ItemType Directory -Path $linkDir -Force | Out-Null

$target   = Join-Path $repo 'Microsoft.PowerShell_profile.ps1'
$existing = Get-Item $link -Force -ErrorAction SilentlyContinue

if ($existing -and $existing.LinkType -eq 'SymbolicLink' -and $existing.Target -contains $target) {
    Write-Host "已链接到 $target，无需重复创建"
}
else {
    if ($existing) {
        if ($existing.LinkType -eq 'SymbolicLink') { Remove-Item $link -Force }  # 旧链接：删掉重建
        else { Move-Item $link "$link.bak" -Force }                              # 普通文件：先备份
    }
    New-Item -ItemType SymbolicLink -Path $link -Target $target
}
```

验证：

```powershell
Get-Item $link | Select-Object LinkType, Target
Get-Content $link -TotalCount 1
```

`LinkType` 显示 `SymbolicLink` 即成功。重开一个 PowerShell 窗口，或执行 `. $PROFILE` 加载。

### 无管理员权限：改用硬链接

在同一磁盘（如都在 C:）上，硬链接不需要管理员权限：

```powershell
New-Item -ItemType HardLink -Path $link -Target (Join-Path $repo 'Microsoft.PowerShell_profile.ps1')
```

硬链接只能用于同一个卷，不能跨盘。

### 使用 cmd 的 mklink

同样需要管理员权限或开发者模式：

```cmd
mklink "%USERPROFILE%\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" "%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
```

### 卸载

```powershell
Remove-Item "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
```

### PowerShell 7 的说明

`powershell.config.json` 只在 PowerShell 7 下生效，需放在用户配置目录（默认 `$HOME\Documents\PowerShell`，可用 `Split-Path $PROFILE.CurrentUserCurrentHost` 查询）。Windows PowerShell 5.1 不会读取这个文件。若仓库不在 PowerShell 7 的配置目录，可用同样的命令把 profile 和 `powershell.config.json` 一并链接过去。
