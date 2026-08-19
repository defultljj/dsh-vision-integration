# 测试报告 — dsh-vision-router 部署预检脚本验证

> **日期**: 2026-08-18
> **测试方式**: 在真实 DSH web profile 上运行 `scripts/verify.ps1`(PowerShell 5.1)

## 📊 测试结果

| 指标 | 结果 |
|------|------|
| 检查项 | 8 通过 / 8 总计 |
| 失败 | 0 |
| 退出码 | 0 |

## 🧪 检查明细

| # | 检查项 | 结果 |
|---|--------|------|
| 1 | profile 目录存在 | ✅ PASS |
| 2 | package.json 存在 | ✅ PASS |
| 3 | 无 UTF-8 BOM(首字节=123) | ✅ PASS |
| 4 | JSON 语法合法 | ✅ PASS |
| 5 | dependencies 已注册 dsh-vision-router | ✅ PASS |
| 6 | dsh.profile.bundles 已注册 | ✅ PASS |
| 7 | node_modules 插件实体存在 | ✅ PASS |
| 8 | 模块加载预检(apply=function) | ✅ PASS |

## 📝 改动文件

| 文件 | 变更说明 |
|------|------|
| `scripts/verify.ps1` | 预检脚本(8 项检查链) |
| `scripts/install.ps1` | 一键部署脚本(备份→官方安装→自动预检) |
| `scripts/recover.ps1` | 崩溃恢复脚本(杀进程→doctor→repair→验证) |

## ⚠️ 已知问题与建议

- Windows PowerShell 5.1 必须用 **UTF-8 with BOM** 保存 `.ps1` 才能正确解析中文注释(无 BOM 会按 ANSI 解析导致乱码)——三个脚本已统一加 BOM,此问题已解决。
- `install.ps1` 与 `recover.ps1` 的破坏性操作(`-Force` 安装、`-Kill` 杀进程)默认关闭,需显式传参,防止误操作。

---

# 复测记录 — 2026-08-19(脚本修复后)

## 修复内容

- `verify.ps1`: 修复模块加载预检块异常路径下 `Pop-Location` 二次弹出目录栈的问题(改为 `try/finally` 结构);`apply` 判定由整行正则改为逐行精确匹配
- `recover.ps1`: `-Kill` 前先打印将被终止的进程列表(名称 + PID),与手册"node 里可能有别的程序"的警告一致

## 复测环境

- Windows PowerShell 5.1,真实 web profile(本机)

## 复测结果

| 指标 | 结果 |
|------|------|
| 检查项 | 8 通过 / 8 总计 |
| 失败 | 0 |
| 退出码 | 0 |

实际输出:

```text
=== dsh-vision-router 预检 ===
Profile: C:\Users\<你的用户名>\.dsh\profiles\web

[PASS] profile 目录存在
[PASS] package.json 存在
[PASS] 无 UTF-8 BOM(首字节=123)
[PASS] JSON 语法合法
[PASS] dependencies 已注册
[PASS] dsh.profile.bundles 已注册
[PASS] node_modules 插件实体存在
[PASS] 模块加载预检(apply=function)

✅ 全部检查通过
```

注:实际输出中的 Windows 用户名已脱敏为 "<你的用户名>"(隐私保护,其余输出未改动)。

---

# 二次修复 — 2026-08-19(终审问题修复)

## 修复内容

| 编号 | 级别 | 修复说明 |
|------|------|------|
| F2 | Important | `verify.ps1` 模块加载预检块补 `catch`:`node` 命令找不到的终止错误转为干净 [FAIL],不再异常退出 |
| F3 | Important | `install.ps1` 安装失败分支改为 try/finally 单次 `Pop-Location`,消除双重弹出;第 3 步改为子进程 `powershell.exe -File` 运行 verify,消除 `exit` 后的死代码 |
| F4 | Important | `recover.ps1` 第 4 步改为子进程运行 verify 并接住退出码,结尾提示与退出码透传不再被 `exit` 截断 |
| F5 | Minor | README mermaid 图删除多余无标签边 `LLM --> ROUTER` |
| F6 | Minor | README 环境表占位符统一为 `C:\Users\<你的用户名>` |
| F7 | Minor | README 结构图注释"可执行代码(全部实测通过)"改为"可执行脚本(verify.ps1 实测通过;install/recover 破坏性操作默认关闭)" |

## 验证结果

| 验证项 | 方法 | 结果 |
|--------|------|------|
| PowerShell 语法(三脚本) | `[scriptblock]::Create((Get-Content -Raw ...))` | verify/install/recover 全部 PARSE_OK,退出码 0 |
| verify.ps1 真实复测 | 本机真实 web profile 运行 | 8/8 PASS,退出码 0 |
| README mermaid 语法 | mermaid.parse(jsdom 环境) | MERMAID_PARSE_OK |

## 实际输出(Step 6② 复测)

```text
=== dsh-vision-router 预检 ===
Profile: C:\Users\<你的用户名>\.dsh\profiles\web

[PASS] profile 目录存在
[PASS] package.json 存在
[PASS] 无 UTF-8 BOM(首字节=123)
[PASS] JSON 语法合法
[PASS] dependencies 已注册
[PASS] dsh.profile.bundles 已注册
[PASS] node_modules 插件实体存在
[PASS] 模块加载预检(apply=function)

✅ 全部检查通过
```

注:实际输出中的 Windows 用户名已脱敏为 "<你的用户名>"(隐私保护,其余输出未改动);复测命令原样运行(GBK 管道下中文乱码),另以 UTF-8 控制台编码复跑一次取得上述可读输出,两次结果一致(8/8 PASS,退出码 0)。
