# 基于 Apple Silicon 的高性能离线 AI 长篇创作系统架构（全栈分析报告）

## 1. 摘要

本报告给出一个**离线优先（Offline-first）**、面向**长篇创作（Long-form Writing）**的桌面端 AI 编辑器架构方案。方案以 Apple Silicon 的统一内存架构（UMA）为基础，将 SwiftUI 的声明式开发效率与 AppKit/TextKit 2 的大文档处理能力深度融合，并通过 Workflow Orchestrator（状态机 + actor）、本地 RAG（检索增强生成）、分层记忆系统、协议化 Skill Registry 与 Core ML/Metal 推理优化形成闭环。

核心目标：

- 大规模文本编辑低延迟（击键到显示 < 16ms）
- 离线语义检索（RAG 检索 < 500ms）
- 首 Token 响应（章节生成 < 2s）
- 长时间离线稳定运行（72h 无泄漏）

---

## 2. 桌面端混合架构性能原语：SwiftUI + AppKit

### 2.1 为什么必须混合架构

- **SwiftUI**：状态绑定、模块化组合、快速迭代。
- **AppKit / NSTextView / TextKit 2**：大文稿编辑、复杂富文本布局、可控渲染路径。

对于数十万至百万字文稿，纯 SwiftUI 文本组件难以覆盖高复杂编辑场景；`NSTextView` + TextKit 2 仍是 macOS 专业编辑器的性能底座。

### 2.2 TextKit 2 的关键能力

- `NSTextStorage`：文本与属性存储。
- `NSTextLayoutManager`：布局计算。
- `NSTextContainer`：渲染容器定义。
- 分片化渲染（Fragmented Rendering）降低主线程压力。
- 支持后台布局与异步分析，避免滚动/输入抖动。

### 2.3 SwiftUI 桥接策略

- 通过 `NSViewRepresentable` 包装 `NSTextView`。
- 建议引入 RichTextKit（或同类桥接层）统一富文本协议。
- 编辑器组件化：输入域、注释层、AI 辅助层、素材侧栏分离。

### 2.4 富内容与可扩展交互

- 使用 `NSTextAttachment` 承载图像、卡片与可交互素材。
- 为 AI 结果预览、引用块、结构化卡片提供原生锚点。

---

## 3. Workflow Orchestrator：异步驱动与状态一致性

### 3.1 actor + 状态机的第一性原理

在 Swift 6 严格并发模型下，Orchestrator 采用：

- **actor 隔离**：保证共享状态并发安全。
- **DFSM（确定性有限状态机）**：统一任务迁移。
- **同步 reduce / 异步执行**：降低重入复杂度。

状态迁移在 `reduce(state:event:)` 中同步决策；耗时任务（推理、检索）在非结构化任务中执行并通过 `send(event:)` 回流。

### 3.2 核心状态机行为（示意）

| 状态 | 关联数据 | 触发事件 | 动作与迁移逻辑 | 置信度 |
|---|---|---|---|---|
| Idle | 无 | StartWorkflow | 检查本地数据层并初始化上下文 | 高 |
| Analyzing | 文稿元数据 | Completion | 调用分析 Skill，产出标签并进入设计 | 高 |
| Designing | 逻辑图谱 | UserUpdate | 拦截编辑更新并触发 DAG 校验 | 中 |
| Drafting | 章节句柄 | RAGRequired | 挂起生成任务，触发离线检索 | 高 |
| Validating | 冲突列表 | RetryRequested | 启动指数退避重试任务 | 中 |

### 3.3 取消与中断处理

- 使用 `withTaskCancellationHandler` 处理章节切换、窗口关闭等取消场景。
- 保障 UI 与后台任务生命周期一致，避免幽灵任务与资源泄漏。

---

## 4. 离线 RAG 内核：摄取、分块、索引

### 4.1 分块策略（Chunking）

- 按语义边界切分（而非固定字符长度）。
- 建议 chunk 大小：**300–800 tokens**。
- 重叠率：**20%–30%**。
- 摄取时补齐元数据：来源、时间、作品阶段、实体标签。

### 4.2 本地向量库选型（Apple Silicon 视角）

| 数据库 | 架构特点 | 优势 | 劣势 | 适用场景 |
|---|---|---|---|---|
| SQLite-vec | C 扩展 + 关系映射 | ACID、零配置、向量与元数据同库 | 超大规模聚类能力一般 | 个人创作工作流 |
| LanceDB | Rust + 列式存储 | 随机 I/O 与多模态表现优秀 | 小库预热存在延迟 | 素材卡片与系列参考库 |
| Qdrant Local | Rust + HNSW | 召回率高、过滤强 | 部署/资源成本更高 | 企业级大向量库 |

### 4.3 可靠性优先建议

若以创作者高频小事务（OLTP）为主，优先 SQLite-vec：

- 事务一致性强；
- 文本更新与向量更新可在同事务内提交；
- 崩溃恢复成本低。

---

## 5. 记忆体系：工作记忆 / 摘要记忆 / 检索记忆

### 5.1 工作记忆（Working Memory）

- 窗口大小：约 4k–8k tokens。
- 滑动窗口随编辑点动态更新。
- 溢出内容不丢弃，转入压缩通道。

### 5.2 摘要记忆（Summary Memory）

层次化压缩：

- 实体级：角色、地点、物品状态变更。
- 段落级：动作与因果链。
- 篇章级：情绪转折与剧情推进。

### 5.3 检索记忆（Retrieval Memory）

当窗口与摘要不足时：

1. 基于任务意图发起本地 RAG；
2. Top-K 检索 + 重排（Re-ranking）；
3. 与当前提示拼装回上下文窗口。

---

## 6. 协议驱动的 Skill Registry

### 6.1 SkillProvider 协议化接口

每个 Skill（如灵感生成、冲突校验）统一实现：

- `capabilityID: String`
- `inputRequirements: Any.Type`
- `execute(context:data:) async throws -> Output`
- `observabilityDelegate`

### 6.2 解耦收益

- Orchestrator 仅依赖能力契约，不依赖实现细节。
- Skill 可独立迭代、灰度切换与离线迁移。
- 可观测性统一采集延迟、Token 用量、错误率。

### 6.3 数据隔离

- 共享物理数据库（SQLite/Realm），逻辑上按命名空间隔离。
- 防止模块越权读写与副作用传播。

---

## 7. 核心功能模块建模

### 7.1 需求分析（Requirements Analysis）

- 解析目标读者、题材定位、卖点与情绪曲线。
- 将用户设想分解为“冲突点 + 情感阈值”作为硬约束。

### 7.2 大纲设计（Plot Planning）

- 三级结构：分幕 → 节点 → 弧线。
- 构建 Logic Graph 并进行 DAG 校验。

### 7.3 内容创作（Content Drafting）

- 续写与改写并行。
- 实时素材推荐（侧栏检索记忆）。
- 角色设定注入维持语气与行为一致。

### 7.4 一致性校验（Consistency Audit）

- 角色设定冲突。
- 时间线冲突。
- 世界观规则冲突。

---

## 8. Apple Silicon 推理优化：Core ML + Metal

### 8.1 嵌入模型量化策略对比

| 方案 | 技术细节 | 延迟收益 | 精度损失（Recall@10） | 结论 |
|---|---|---|---|---|
| FP16 | 浮点基线 | 1x | 0% | 质量基线 |
| INT8 | 线性量化，适配神经引擎 | 2.5x–3.0x | < 2% | 推荐默认 |
| A8W4 | 权重 4-bit + 激活 8-bit | 4x+ | 5%–8% | 需场景验证 |
| Matryoshka | 学习型降维 | 检索提速约 5x | 低 | 适合大库检索 |

### 8.2 运行时内存治理

- 进入编辑态：异步预热嵌入模型。
- 闲置超时（如 5 分钟）：释放权重。
- 基于 UMA 快速换入换出（目标 < 500ms 体感切换）。

---

## 9. 出版管线：DocX / EPUB / PDF

### 9.1 DocX（OpenXML）

- 从 `NSAttributedString` 精确映射字体、段落、附件。
- 保持审稿与排版兼容。

### 9.2 EPUB 3

- 自动封面、目录、Dublin Core 元数据。
- 适配重排版阅读场景。

### 9.3 PDF（印刷导向）

- 多栏版式（`NSTextContainer`）。
- 字体嵌入保证跨设备一致。
- 自动页码、注脚、索引锚点。

---

## 10. 分阶段落地路线

1. **阶段一：编辑基座**
   - SwiftUI 包装 NSTextView。
   - SQLite 增量存储与大库快速打开。
2. **阶段二：离线语义大脑**
   - 部署 Core ML 嵌入模型。
   - 完成 chunk 与索引版本管理。
3. **阶段三：Orchestrator + Skills**
   - 接入 Skill Registry。
   - 上线需求分析与大纲设计能力。
4. **阶段四：一致性 + 出版闭环**
   - 集成记忆压缩算法。
   - 上线跨章节校验与多格式导出。

---

## 11. 质量评估指标（QA）

- Recall@K ≥ 85%
- Coherence Score（LLM-as-a-judge）持续提升
- 击键延迟 < 16ms
- RAG 检索 < 500ms
- 章节生成首 Token < 2s
- 无网连续运行 72h 无泄漏
- 嵌入版本迁移成功率 100%

---

## 12. 结论

该架构以“本地优先 + 高并发安全 + 检索增强 + 可出版闭环”为核心，能够将 AI 从“段落补全器”升级为“全流程创作副驾驶”。在 Apple Silicon 持续提升端侧算力的背景下，此类离线优先架构将成为专业创作软件的主流范式。
