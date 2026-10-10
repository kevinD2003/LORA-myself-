# 历史维护脚本

[queue_stage26_next_worker.ps1](queue_stage26_next_worker.ps1) 是 Stage26 历史 MATLAB 排队启动脚本，保留用于查阅旧运行方式。

截至 2026-10-08，脚本硬编码的 `E:\Matlab2022\MATLAB2022\bin\matlab.exe` 和 `results/stage26_formal_ber` 在当前机器/项目中不存在；默认等待 PID 也是历史值。重用前必须检查这些参数。整理仅移动脚本，内容保持原样。

当前项目验证入口是 [runStage55ProjectTests.m](../../runStage55ProjectTests.m)，参见 [Stage55 README](../../README.md)。
