# Agent Guide

本文件用于告诉 Agent 如何理解仓库、如何工作，以及每份文档的职责。

## 工作原则

- 默认使用简体中文沟通
- 修改代码时保持代码与文档一致
- 优先遵循 clean architecture 与 DDD 分层
- 规则逻辑放在 `domain`，流程编排放在 `application`，渲染与交互放在 `presentation`
- 函数必须带函数头注释，解释功能、调用场景、主要逻辑

## 文档索引

- `readme.md`：项目简介、运行方式、目录结构
- `claude.md`：面向 Agent 的实现补充约束与编码约定
- `docs/product.md`：产品文档，记录目标用户、核心玩法、交互闭环与当前功能清单
- `docs/technical.md`：技术文档，记录运行时结构、关键模块、数据流和主要实现约束
- `docs/overview.md`：原型定位、设计目标、当前体验边界
- `docs/gameplay.md`：玩法规则、交互目标、胜负与节奏边界
- `docs/architecture.md`：项目分层、模块职责、依赖方向
- `docs/runbook.md`：本地运行、调试建议、验证清单
- `docs/testing.md`：测试策略、覆盖目标、验证方式
- `docs/agent_lessons.md`：Agent 复盘记录，用于持久化总结错误与规避方式

## 当前项目理解

这是一个手机竖屏的轻策略攻防原型。地图上存在随机城市节点和道路连接，玩家与多个独立电脑势力围绕城市占领、运兵、道路行军和战线推进进行对抗。
