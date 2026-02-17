# LongformAI

基于《apple-silicon-offline-ai-longform-architecture.md》的项目初始化实现。

## 当前阶段（Bootstrap）

- 建立 Swift Package 工程骨架
- 实现 Workflow Orchestrator（actor + DFSM）
- 实现 Skill Registry 协议层（协议驱动）
- 实现离线 RAG 的简化分块器（300-800 token 思路的可配置版）
- 实现三层记忆模型（Working / Summary / Retrieval）
- 提供 InMemory Repository 作为后续 SQLite-vec 持久层替身
- 强化并发约束：SkillProvider 恢复 Sendable 语义，观测回调限制在 MainActor

## 目录

- `Sources/LongformAI/Workflow`：流程编排
- `Sources/LongformAI/Skills`：能力协议与注册
- `Sources/LongformAI/RAG`：分块与检索前置
- `Sources/LongformAI/Memory`：记忆分层
- `Sources/LongformAI/Storage`：仓储抽象
- `Sources/LongformAI/Models`：领域模型

## 运行测试

```bash
swift test
```
