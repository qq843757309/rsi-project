# RSI 数据平台存储、采集与自进化资产选型补充 v4.0

日期：2026-10-03。配套 PPT 保留 v3.0 五页架构，新增选型和实现章节。

## 建设前提

公司内网部署；OceanBase MySQL 兼容、约 3000 张明细表和少量挂测总表；50 用户；AD、内网 LLM 和文本 embedding 已有。NAS 是当前非结构化数据来源。图片/音频规模、内网视觉与 ASR 模型、Git/制品服务和 OceanBase 具体版本未确认，不据此臆定采购和容量。

“原数据”按原始文件与元数据两部分落地：原件保存字节级版本，元数据保存资产身份、来源、权限、处理与发布状态。

## 结构化实验数据：替代与补充方案

| 方案 | 能力 | 边界 | 建议 |
|---|---|---|---|
| Excel → OceanBase → API | 保留现有写入链路；在只读视图和业务语义层之上查询。 | 目录 / 单位 / 关联治理仍需建设；数据库 MySQL 兼容不等于所有插件兼容。 | 一期推荐保留 |
| MySQL / PostgreSQL 关系库 | 作为替代业务库，或工具专用后端；统一实验类型的主题模型。 | 迁移、SQL 适配与双写成本；PG 专用组件不能直接改接 OceanBase。 | 有明确缺口再迁移 |
| OceanBase + 分析副本 | 长范围统计和曲线分析从生产查询隔离；可评估 ClickHouse。 | 同步、口径、延迟和权限治理；分析副本不接管填报事务。 | 分析负载瓶颈时 |
| Parquet / Iceberg + 查询引擎 | 历史快照、训练样本与跨域批分析；DuckDB 适合离线实验分析。 | 需额外目录、快照和批处理；不能代替多人在线事务入口。 | 二期分析 / 训练 |
| OceanBase 原生向量候选 | 官方 4.3.5 文档包含 MySQL 租户向量 SQL 能力。 | 当前安装版本与索引、过滤、融合检索能力未核实；需专项 PoC。 | 与独立检索方案对比 |

**建议：** 3000 张表的首要问题是语义与关联治理。先组织表族与批准视图，新增实验逐步规范模型，不因表数直接更换数据库。

参考：[DuckDB concurrency](https://duckdb.org/docs/current/connect/concurrency)；[Iceberg snapshots](https://iceberg.apache.org/docs/latest/branching/)；[OceanBase vector SQL](https://en.oceanbase.com/docs/common-oceanbase-database-10000000001976352)；[ClickHouse columnar](https://clickhouse.com/resources/engineering/when-to-use-columnar-database)。

## 非结构化原件：NAS 与对象存储路径

| 方案 | 能力 | 边界 | 建议 |
|---|---|---|---|
| A 保留 NAS + 目录登记 | 原件留业务共享盘；平台扫描、hash、权限映射，登记稳定资产 ID。 | 覆盖 / 改名 / 删除影响历史证据；NAS ACL 与项目授权需同步。 | 快速接入，过渡方案 |
| B NAS → 受控原件副本 | 业务继续用 NAS；平台复制正式版本到独立存储，再解析和索引。 | 存在两份数据；需定义正式版本、更新周期、撤回和保留责任。 | 一期优先路径 |
| C 上传直达对象存储 | 原件存私有 S3，关系库存元数据；版本 / 上传 / 生命周期由平台管理。 | 改变业务上传入口；对象版本、下载鉴权和备份需实现与测试。 | 新上传优先采用 |
| D 企业内容管理系统 | 利用既有文档审批、版本和权限系统，通过接口同步。 | 当前未确认有此系统；连接器、许可与跨系统授权需评估。 | 已有成熟系统时复用 |

**建议：** 建议保留 NAS 作为业务来源，正式入库原件保存受控版本副本。NAS 路径和对象 Key 都不是业务资产 ID。

参考：[S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)；[Ceph RGW](https://docs.ceph.com/en/latest/radosgw/index.html)；[SeaweedFS](https://github.com/seaweedfs/seaweedfs)。

## 私有对象存储：产品选型对比

| 方案 | 能力 | 边界 | 建议 |
|---|---|---|---|
| Ceph RGW | S3 / Swift 接口，适合统一的私有存储基础设施。 | 集群、磁盘和恢复运维较重；已有 Ceph 团队时更有利。 | 企业已有基础时优先 |
| SeaweedFS | 文件与 S3 接口，可采用分布式部署。 | 生产拓扑、元数据后端、权限、版本和恢复需实际验证。 | 试点新建 PoC 候选 |
| 商业对象存储 / MinIO AIStor | 采购支持、交付与服务保障；按合同及能力选择。 | 预算、产品许可、离线授权、AD 集成及维护支持分别核实。 | 需要厂商支持时 |
| 历史 MinIO 开源版本 | 已有环境可作为兼容性与迁移评估对象。 | 官方声明开源产品自 2025-09 起停止维护；需维护、补丁及替换方案。 | 不作新建默认推荐 |

**建议：** 按能力验收：版本/生命周期、完整性校验、断点上传、访问审计、权限撤回、备份恢复。S3 兼容不等于每项能力一致。

参考：[Ceph RGW](https://docs.ceph.com/en/latest/radosgw/index.html)；[SeaweedFS](https://github.com/seaweedfs/seaweedfs)；[MinIO maintenance](https://www.min.io/legal)。

## 多模态与向量检索：数据库对比

| 方案 | 能力 | 边界 | 建议 |
|---|---|---|---|
| OpenSearch | 全文 / 文档关键词 + 语义检索；利用现有文档检索路径。 | 多模态需外部模型与字段设计；权限、重排和版本同步仍需服务层实现。 | 文档查询优先候选 |
| Qdrant | 命名向量、元数据过滤，适合多表示的向量检索服务。 | 全文引擎与向量服务可能分开；不负责 PDF 或音频原件的生命周期。 | 独立向量 PoC 候选 |
| Milvus | 多向量字段及融合搜索；适合文本、图像等向量组合。 | 部署形态、索引成本和过滤性能按真实负载测试；不自动产生多模态向量。 | 多向量需求明确时 |
| Lance / LanceDB | 多模态数据集、向量与训练数据读取；OSS 和企业版形态不同。 | 嵌入式库与企业服务不能混为一谈；多人在线访问、权限和部署模式需核验。 | 二期多模态 / 训练 |
| OceanBase 原生 / PG + pgvector | 复用关系查询或建立 PG 向量后端，减少部分数据链路。 | OB 能力受版本约束；pgvector 要新增 PostgreSQL，不是 OB 插件。 | 作为整合路线 PoC |

**建议：** 选择依据：授权过滤后的召回、图文对齐、更新 / 撤回一致性、索引重建、活跃并发和运维成本，不用统一向量数量阈值选型。

参考：[OpenSearch Hybrid Search](https://docs.opensearch.org/latest/vector-search/ai-search/hybrid-search/index/)；[pgvector](https://github.com/pgvector/pgvector)；[Milvus multi-vector](https://milvus.io/docs/multi-vector-search.md)；[Qdrant vectors](https://qdrant.tech/documentation/manage-data/vectors/)；[LanceDB](https://docs.lancedb.com/)；[OceanBase vector SQL](https://en.oceanbase.com/docs/common-oceanbase-database-10000000001976352)。

## 业务侧采集：不同入口的实施方案

| 方案 | 能力 | 边界 | 建议 |
|---|---|---|---|
| 已有 Excel 脚本适配 | 补 import_batch、模板映射版本、源文件引用、幂等键和逐行错误。 | 盘点现有脚本；失败重跑不得重复写入；重要写入事务化。 | 一期保留并统一契约 |
| 页面 / API 填报 | 结构化模板、草稿、预校验、受限提交、修订旧值及附件。 | 与脚本使用同一单位和标识；写接口与查询只读身份分离。 | 一期建设 |
| NAS 增量扫描 / 上传 | 快照扫描、内容 hash、覆盖版本判定、项目 ACL 映射与撤回事件。 | 扫描不是瞬时 CDC；活跃修改文件需稳定读取与重试策略。 | 一期接入主路径 |
| 仪器 / ELN / LIMS / CDC | 外部接口或事件驱动采集，按业务时效补流式入口。 | 尚未确认已有系统；协议、标识、时序和保留规则需专门适配。 | 后续按数据源启用 |

**建议：** 业务采集统一输出：submission / import_batch / asset_version / source_ref / quality_report / lineage_event；只对正式发布版本开放查询。

参考：。

## Agent 轨迹：Langfuse、Phoenix 与 DuckDB

| 方案 | 能力 | 边界 | 建议 |
|---|---|---|---|
| Langfuse 自托管 | Trace、评分、数据集及 Prompt 工作台；面向统一 Agent 观测。 | 当前官方架构含 Postgres、ClickHouse、Redis/Valkey、S3；许可和 AD 接入按版本核验。 | Prompt + 观测需求强时 |
| Phoenix 自托管 | 轨迹采集与分析；支持 SQL 后端，适合排查检索 / 工具与评测问题。 | 本地 SQLite；官方建议生产多人场景用 PostgreSQL。需验证鉴权、AD 和数据权限。 | 较少存储依赖的 PoC |
| DuckDB + Parquet | 离线 Trace 导出分析、错误聚合、样本构建和科研分析。 | 它是分析引擎；嵌入式多写线程在一个进程内，远程协议成熟度按安装版核验。 | 辅助分析，非主工作台 |
| 自建事件接收 + 业务目录 | 最小 Trace Schema、对象归档、查询链接与指标，复用现有基础。 | 工作台、评测和 Prompt 运营功能需要自研；维护负担随需求增长。 | 最小采集兜底方案 |

**建议：** 先统一采集，再用同一批真实轨迹比较 Phoenix 与 Langfuse，选择一个主工作台；DuckDB 做离线分析。不默认两套同时长期运行。

参考：[Langfuse Self-hosting](https://langfuse.com/self-hosting)；[Phoenix architecture](https://arize.com/docs/phoenix/self-hosting/architecture)；[DuckDB concurrency](https://duckdb.org/docs/current/connect/concurrency)。

## 记忆方案：自建、Mem0 与框架持久化

| 方案 | 能力 | 边界 | 建议 |
|---|---|---|---|
| 自建记忆 API + OceanBase | 状态与经验结构化管理，检索复用全文 / 向量；契合专家审核流程。 | 需开发提取、冲突、过期、删除、授权和召回策略。 | 一期权威记忆推荐 |
| Mem0 OSS + 内网模型 | 以库或自托管服务部署，配置 LLM、embedding、向量后端；图记忆可选。 | 默认示例不等于适配内网模型；审核与项目隔离需补，图后端会新增依赖。 | 经验候选提取 PoC |
| LangGraph Checkpointer / Store | 线程状态持久化与恢复，长期 Store 管理跨线程内容。 | 不是专家知识审批系统；框架官方 PG 适配不等于支持 OceanBase，需自定义或新增后端。 | 已有框架时复用 |
| OpenAI Conversations 等托管接口 | 管理 OpenAI API 的会话状态；应用也可自管消息上下文。 | 托管 API 路径依赖外部服务；当前严格内网条件下不纳入生产方案。 | 仅作能力模式参考 |

**建议：** 一期先实现有证据和审核的记忆资产；自动总结生成候选，不覆盖专家意见。存储层、提取引擎与框架接口分开选型。

参考：[Mem0 OSS](https://docs.mem0.ai/open-source/overview)；[LangGraph persistence](https://docs.langchain.com/oss/python/langgraph/persistence)；[OpenAI conversation state](https://developers.openai.com/api/docs/guides/conversation-state)。

## 代码、Prompt 与可执行制品选型

| 方案 | 能力 | 边界 | 建议 |
|---|---|---|---|
| Git + 内网流水线 / 制品库 | 源码与小配置由 Commit 管理；镜像 / wheel / 包按版本和 digest 发布。 | 不把训练权重直接塞入普通 Git；公司是否已有 Git 服务仍需实施盘点。 | 基础必需，优先复用 |
| Git 管理 Prompt + 配置发布 | 模板文本、变量、工具 Schema 共同评审；运行绑定版本。 | 需要简单注册、别名、评测和回滚入口；不能只记录“latest”。 | 一期最小方案 |
| Langfuse Prompt 工作台 | Prompt 版本与调用观测联接，适合非代码人员参与迭代。 | 已选 Langfuse 才有复用优势；内网模型调用、权限和许可证需验证。 | 随观测主平台选用 |
| MLflow Prompt Registry | Prompt 注册、版本与实验关联，适合统一评测 / 模型治理。 | 新增 MLflow 或扩大其管理范围；避免与 Git / Langfuse 重复权威版本。 | 已有 MLflow 时优先 |

**建议：** 确定唯一权威版本与发布清单。工作台可读镜像或管理别名，发布时解析到固定 prompt_version、code_commit 和 artifact_digest。

参考：[Langfuse Self-hosting](https://langfuse.com/self-hosting)；[MLflow Prompt Registry](https://mlflow.org/docs/latest/genai/prompt-registry/)；[GitLab Registry](https://docs.gitlab.com/user/packages/package_registry/)。

## 模型与训练 Checkpoint：存储管理选型

| 方案 | 能力 | 边界 | 建议 |
|---|---|---|---|
| 私有对象存储 + 模型目录 | 模型、Tokenizer、Adapter、分片文件及 manifest 持久化；目录保存状态与引用。 | 上传原子性、hash 校验、生命周期、下载带宽和恢复需测试。 | 推荐制品保存基础 |
| MLflow Registry + Artifact Store | Run、参数、指标、模型版本与大文件分离；可使用 S3 兼容或 NFS。 | 注册元数据需要后端；MySQL 支持不等于 OceanBase 已认证兼容；权限需端到端设计。 | 启用模型进化时 PoC |
| Git + DVC + 大文件存储 | Git 保存数据 / 模型版本引用，实际大文件存远端或内网存储。 | 适合数据和代码共版；不等于在线模型发布、审批和观测平台。 | 训练数据版本候选 |
| 训练区 NAS / 并行文件系统 | 面向高吞吐续训和共享工作目录；按作业加载 / 写入快照。 | 适合作业热存储；权威归档和生命周期仍需目录与大文件存储。 | 高训练 IO 场景 |

**建议：** 区分三类：推理模型制品、训练恢复 Checkpoint、Agent 会话 Checkpoint。分别采用模型注册、训练 manifest 和状态持久化契约。

参考：[MLflow artifacts](https://mlflow.org/docs/latest/self-hosting/architecture/artifact-store/)；[DVC](https://doc.dvc.org/user-guide)；[PyTorch Checkpoint](https://docs.pytorch.org/tutorials/beginner/saving_loading_models.html)。

## 采集设计

业务采集使用已有入库脚本适配、结构化页面/API、NAS 扫描和受控上传四类入口。统一登记项目、批次、模板、源资产版本、提交修订与任务状态。NAS 活跃修改文件需稳定读取或快照，不把事件通知当作完整一致性保证。正式原件采用受控副本，原位和平台副本的权威版本与保留责任明确。

Agent 埋点覆盖请求、公开 LLM 调用、工具、SQL、检索、模型/Prompt/工具版本、反馈、评测和发布。可经 OTel Collector 或产品 SDK 接收，采用队列/批量/幂等/重试及对账。协议与属性兼容需实际 PoC；不直接假定可向所有工作台同样导入。业务审计和血缘记录可靠完整，性能观测可采样；采样 Trace 不能冒充完整业务血缘。

## 多模态设计

原图、原音频、裁剪、缩略图、转写及分段附件由大文件存储管理。文档保留页码、幻灯片、表格和坐标，音频保留时间戳与采样率。全文索引管理 OCR/ASR，向量索引管理各表示的向量。embedding 的 model/version/dimension/distance/modality 应登记；不同模型空间不能直接比较。先完成可定位文本检索，再按任务增加图像或音频检索。

## 元数据实体草案

asset(asset_id, type, project, owner, classification, status)；asset_version(version_id, asset_id, parent_version, hash, storage_uri, mime, size, source_uri)；segment(segment_id, version_id, page, slide, bbox, start_ms, end_ms, text_ref)；processing_run(run_id, inputs, outputs, parser_version, chunker_version, embedding_version, quality_ref)。

agent_run(trace_id, query_id, principal, project, external_ref, version_manifest)；span(span_id, parent_span_id, tool_ref, model_ref, prompt_ref, evidence_refs, status)；memory_item(memory_id, kind, namespace, source_refs, valid_scope, review_status, supersedes, ttl)；candidate(candidate_id, parent_ids, code_commit, change_reason, prompt_ref, model_ref, artifact_digest)。

training_checkpoint(training_run_id, step, base_model_ref, dataset_snapshot, optimizer_ref, manifest_ref, hashes)；eval_run(eval_run_id, dataset_snapshot, rubric_version, candidate_refs, per_case_results)；release_manifest(release_id, commit, prompt_version, tool_version, model_digest, dataset_snapshot, index_version, policy_version, evaluator_refs, approver, rollback_ref)。

这些是逻辑设计，不是已存在的数据库表。OceanBase 适配、索引、JSON 字段和大表拆分由实际版本与负载验证。模型制品、训练 Checkpoint 和会话 Checkpoint 分别管理，禁止只用同一个“checkpoint”字段而不说明类型。

## 自进化资产的阶段边界

一期先登记调用、失败、反馈、经验确认、评测与配置版本。代码技能进化增加 Git Commit、依赖锁、构建镜像、工具 Schema、沙箱与测试。模型进化再增加训练/开发/测试隔离、数据快照、基础模型引用、权重/Adapter/Tokenizer、训练恢复状态及模型注册。训练 Checkpoint 按框架恢复需求保存优化器、调度器、步数等状态；训练热存储与权威归档分开。

## 一期组合建议

保留 OceanBase 作为业务与目录基础。NAS 为业务来源，正式文件有受控副本；新上传优先通过独立资产 API。私有 S3 在 Ceph/SeaweedFS/商业方案之间 PoC。全文与向量检索选一个一期组合；与 OceanBase 原生向量能力比较时锁定现网版本。Phoenix 与 Langfuse 比较后选择一个主工作台，DuckDB 用于离线 Parquet 分析。记忆权威条目用自建目录和专家审核，Mem0 可用于生成候选。Prompt 先以 Git 固定版本，已有主平台时再选 Registry。模型进化阶段评估 MLflow/DVC，避免重复权威版本。

不能用公司内网的 OceanBase 强替换各产品官方要求的 PostgreSQL 或其他后端。新增 PostgreSQL 是工具依赖决策，不等同于迁移业务库。AD 登录还需要平台项目和数据授权；对象版本化、Git 和 Trace 不能分别代替统一血缘与发布 manifest。

## 资料索引

- [S01 NOMAD ELN](https://docs.nomad-lab.eu/howto/manage/gui/eln.html)：科学数据 Schema、ELN 与外部 ELN 对接。
- [S02 S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)：对象多版本与删除标记，作为接口能力参考，不推荐云端部署。
- [S03 OpenMetadata Data Contracts](https://docs.open-metadata.org/v1.12.x/api-reference/data-contracts)：Schema、质量和语义契约，产品集成需核查。
- [S04 dbt Semantic Layer](https://docs.getdbt.com/docs/use-dbt-semantic-layer/dbt-sl)：统一指标和关联语义的参考，非直接兼容承诺。
- [S05 DoclingDocument](https://docling-project.github.io/docling/concepts/docling_document/)：统一文档表示与来源位置。
- [S06 Great Expectations Checkpoints](https://docs.greatexpectations.io/docs/core/trigger_actions_based_on_results/create_a_checkpoint_with_actions/)：数据验证和结果驱动动作。
- [S07 SQLGlot](https://github.com/tobymao/sqlglot)：SQL 解析和 AST 分析，需自行实现授权与语义检查。
- [S08 OpenSearch Hybrid Search](https://docs.opensearch.org/latest/vector-search/ai-search/hybrid-search/index/)：全文与语义检索融合。
- [S09 OpenSearch DLS](https://docs.opensearch.org/latest/security/access-control/document-level-security/)：文档读权限，写操作仍需要独立授权。
- [S10 Qdrant Hybrid Queries](https://qdrant.tech/documentation/search/hybrid-queries/)：向量/稀疏检索融合与查询组合。
- [S11 pgvector](https://github.com/pgvector/pgvector)：PostgreSQL 向量扩展，非 MySQL/OceanBase 插件。
- [S12 Reflexion](https://arxiv.org/abs/2303.11366)：反馈与情景记忆研究，未证明材料研发收益。
- [S13 MLflow Evaluation Datasets](https://mlflow.org/docs/latest/genai/datasets/)：评测数据集与运行记录关联。
- [S14 Langfuse Self-hosting](https://langfuse.com/self-hosting)：本轮官方页面显示 v4，自托管涉及 Postgres、ClickHouse、Redis/Valkey、对象存储。
- [S15 Keycloak AD / LDAP](https://www.keycloak.org/docs/26.8.0/server_admin/)：身份联邦候选，现有 SSO 可用时无需新增。
- [S16 MCP Tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools)：工具发现和调用契约，不代替业务授权。
- [S17 OpenLineage](https://openlineage.io/docs/spec/examples/)：Job、Run、Dataset 与输入输出关系。
- [S18 Airflow Architecture](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/overview.html)：DAG 调度与任务执行分工。
- [S19 DGM](https://arxiv.org/abs/2505.22954)：代码候选、档案与编码 benchmark 的实证验证研究。
- [S20 AiiDA](https://arxiv.org/abs/2003.12476)：科学计算自动化及数据来源追踪。
- [S21 AIMD-L](https://hemi.jhu.edu/caimee/center-facilities/aimd-l/data-handling/)：事件数据关联样品生命周期。
- [S22 OpenTelemetry Semantic Conventions](https://opentelemetry.io/docs/concepts/semantic-conventions/)：统一遥测属性，GenAI 字段需锁定实际采用版本。
- [S23 Phoenix architecture](https://arize.com/docs/phoenix/self-hosting/architecture)：轨迹观测，SQLite 与 PostgreSQL 后端。
- [S24 DuckDB concurrency](https://duckdb.org/docs/current/connect/concurrency)：嵌入式写入模型；远程并发协议需按版本核验。
- [S25 Ceph RGW](https://docs.ceph.com/en/latest/radosgw/index.html)：内网对象存储的 S3 / Swift 接口。
- [S26 SeaweedFS](https://github.com/seaweedfs/seaweedfs)：S3 与文件存储，可自部署。
- [S27 MinIO maintenance](https://www.min.io/legal)：官方声明开源产品已于 2025-09 停止维护。
- [S28 Milvus multi-vector](https://milvus.io/docs/multi-vector-search.md)：多向量字段与融合检索。
- [S29 Qdrant vectors](https://qdrant.tech/documentation/manage-data/vectors/)：命名向量及不同表示的管理。
- [S30 LanceDB](https://docs.lancedb.com/)：Lance 格式与多模态；OSS / Enterprise 边界需区分。
- [S31 Mem0 OSS](https://docs.mem0.ai/open-source/overview)：库或自托管服务，配置模型与向量后端。
- [S32 LangGraph persistence](https://docs.langchain.com/oss/python/langgraph/persistence)：线程状态、Checkpoint 与运行恢复。
- [S33 OpenAI conversation state](https://developers.openai.com/api/docs/guides/conversation-state)：托管会话状态接口，非公司内网记忆数据库。
- [S34 MLflow artifacts](https://mlflow.org/docs/latest/self-hosting/architecture/artifact-store/)：元数据与大文件存储分离，支持 S3 兼容与 NFS。
- [S35 DVC](https://doc.dvc.org/user-guide)：Git 中记录大文件版本引用，实际数据另存。
- [S36 MLflow Prompt Registry](https://mlflow.org/docs/latest/genai/prompt-registry/)：Prompt 版本与注册管理。
- [S37 GitLab Registry](https://docs.gitlab.com/user/packages/package_registry/)：制品发布与流水线、Commit 关联。
- [S38 OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)：采集、处理与导出遥测。
- [S39 Docling formats](https://docling-project.github.io/docling/usage/supported_formats/)：PDF / DOCX / PPTX 等解析支持，旧格式需转码验证。
- [S40 Iceberg snapshots](https://iceberg.apache.org/docs/latest/branching/)：分析数据快照与生命周期。
- [S41 OceanBase vector SQL](https://en.oceanbase.com/docs/common-oceanbase-database-10000000001976352)：4.3.5 文档介绍 MySQL 租户向量 SQL，现网版本需核验。
- [S42 PyTorch Checkpoint](https://docs.pytorch.org/tutorials/beginner/saving_loading_models.html)：续训快照包含权重之外的优化器与训练状态。
- [S43 ClickHouse columnar](https://clickhouse.com/resources/engineering/when-to-use-columnar-database)：面向聚合分析的列式存储。
