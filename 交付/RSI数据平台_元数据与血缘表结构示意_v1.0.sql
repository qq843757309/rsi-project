-- RSI 元数据与血缘表结构示意 v1.0，2026-10-03。
-- 讨论稿，未在 OceanBase 现网执行验证。
-- 由研发选择开发逻辑库后评审执行。本文件不 CREATE DATABASE，不 DROP，不修改业务表。
-- 本示例不包含完整的权限、契约、质量、事件消费去重和审计体系。
-- id 为应用生成的稳定 ID。扩展 JSON 由服务校验，存在 LONGTEXT 中。
-- 无外键示例的引用完整性须由服务与对账保证。

-- 1 来源系统。address_ref 为受控配置引用，不存密码。
CREATE TABLE meta_source (
  source_id VARCHAR(64) NOT NULL,
  source_type VARCHAR(32) NOT NULL,
  source_name VARCHAR(255) NOT NULL,
  address_ref VARCHAR(512) NULL,
  owner_principal VARCHAR(128) NOT NULL,
  status VARCHAR(32) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  PRIMARY KEY (source_id)
);

-- 2 逻辑资产。current_version_id 通过已验证的发布流程更新。
CREATE TABLE meta_asset (
  asset_id VARCHAR(64) NOT NULL,
  asset_type VARCHAR(32) NOT NULL,
  team_id VARCHAR(64) NOT NULL,
  project_id VARCHAR(64) NOT NULL,
  source_id VARCHAR(64) NULL,
  asset_name VARCHAR(255) NOT NULL,
  owner_principal VARCHAR(128) NOT NULL,
  classification VARCHAR(64) NOT NULL,
  policy_ref VARCHAR(128) NOT NULL,
  current_version_id VARCHAR(64) NULL,
  status VARCHAR(32) NOT NULL,
  catalog_revision BIGINT NOT NULL DEFAULT 0,
  extensions_json LONGTEXT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  PRIMARY KEY (asset_id),
  KEY ix_asset_scope (team_id, project_id, asset_type, status),
  KEY ix_asset_source (source_id)
);

-- 3 确定资产版本。内容不静默覆盖，状态依状态机变化。
-- version_kind 区分 FILE_CONTENT、TABLE_SCHEMA、DATA_RANGE、DATA_SNAPSHOT、
-- RECORD_REVISION、SEGMENT_CONTENT、MEMORY_CONTENT、RESULT_CONTENT 等。
-- DATA_RANGE 仅说明定位范围，restore_mode 表示是否能恢复数据值。
CREATE TABLE meta_asset_version (
  version_id VARCHAR(64) NOT NULL,
  asset_id VARCHAR(64) NOT NULL,
  version_no BIGINT NOT NULL,
  version_kind VARCHAR(32) NOT NULL,
  parent_version_id VARCHAR(64) NULL,
  contract_ref VARCHAR(128) NOT NULL,
  source_key VARCHAR(512) NULL,
  storage_ref VARCHAR(1024) NULL,
  content_hash CHAR(64) NULL,
  hash_algorithm VARCHAR(32) NULL,
  byte_size BIGINT NULL,
  mime_type VARCHAR(128) NULL,
  schema_ref VARCHAR(128) NULL,
  restore_mode VARCHAR(32) NOT NULL,
  locator_json LONGTEXT NULL,
  quality_state VARCHAR(32) NOT NULL,
  quality_result_ref VARCHAR(128) NULL,
  state VARCHAR(32) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  PRIMARY KEY (version_id),
  UNIQUE KEY uq_asset_version (asset_id, version_no),
  KEY ix_version_parent (parent_version_id),
  KEY ix_version_asset_state (asset_id, state)
);

-- 4 字段目录，每一行属于确定的 TABLE_SCHEMA 版本。
-- datatype 和结构可自动采集，单位、含义、粒度需要业务确认。
CREATE TABLE meta_field (
  field_id VARCHAR(64) NOT NULL,
  asset_version_id VARCHAR(64) NOT NULL,
  field_name VARCHAR(128) NOT NULL,
  ordinal_position INT NOT NULL,
  data_type VARCHAR(128) NOT NULL,
  nullable_flag TINYINT NOT NULL,
  unit_code VARCHAR(64) NULL,
  business_meaning TEXT NULL,
  grain_description VARCHAR(512) NULL,
  missing_semantics VARCHAR(512) NULL,
  semantic_state VARCHAR(32) NOT NULL,
  mapping_ref VARCHAR(128) NULL,
  PRIMARY KEY (field_id),
  UNIQUE KEY uq_schema_field (asset_version_id, field_name)
);

-- 5 处理运行。实际 SQL、参数和大结果用受控引用，避免目录保存敏感全文。
CREATE TABLE meta_processing_run (
  run_id VARCHAR(64) NOT NULL,
  team_id VARCHAR(64) NOT NULL,
  project_id VARCHAR(64) NOT NULL,
  job_id VARCHAR(128) NOT NULL,
  job_version VARCHAR(128) NOT NULL,
  run_type VARCHAR(32) NOT NULL,
  agent_run_id VARCHAR(64) NULL,
  principal_ref VARCHAR(128) NOT NULL,
  config_ref VARCHAR(512) NULL,
  execution_ref VARCHAR(512) NULL,
  status VARCHAR(32) NOT NULL,
  started_at DATETIME(6) NOT NULL,
  finished_at DATETIME(6) NULL,
  error_ref VARCHAR(512) NULL,
  PRIMARY KEY (run_id),
  KEY ix_run_scope_time (team_id, project_id, started_at),
  KEY ix_run_agent (agent_run_id),
  KEY ix_run_status (status, started_at)
);

-- 6 Run 的输入输出事实。ordinal_no 对一次 Run 的 IO 项稳定编号，以便幂等。
-- locator_json 保存单元格、页码、字段或读取记录范围，不自动等于数据快照。
CREATE TABLE meta_run_io (
  io_id VARCHAR(64) NOT NULL,
  run_id VARCHAR(64) NOT NULL,
  direction VARCHAR(16) NOT NULL,
  ordinal_no INT NOT NULL,
  asset_version_id VARCHAR(64) NOT NULL,
  locator_json LONGTEXT NULL,
  data_snapshot_ref VARCHAR(512) NULL,
  capture_method VARCHAR(32) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  PRIMARY KEY (io_id),
  UNIQUE KEY uq_run_io_ordinal (run_id, direction, ordinal_no),
  KEY ix_io_asset (asset_version_id, direction)
);

-- 7 血缘查询投影。由实际 Run 和映射生成，不对全部输入输出盲目做笛卡尔积。
-- mapping_key 为应用生成的稳定映射键，支持不同定位/字段关系去重。
CREATE TABLE meta_lineage_edge (
  edge_id VARCHAR(64) NOT NULL,
  team_id VARCHAR(64) NOT NULL,
  project_id VARCHAR(64) NOT NULL,
  input_version_id VARCHAR(64) NOT NULL,
  output_version_id VARCHAR(64) NOT NULL,
  run_id VARCHAR(64) NOT NULL,
  relation_type VARCHAR(32) NOT NULL,
  mapping_key VARCHAR(64) NOT NULL,
  source_field_id VARCHAR(64) NULL,
  target_field_id VARCHAR(64) NULL,
  locator_json LONGTEXT NULL,
  verification_status VARCHAR(32) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  PRIMARY KEY (edge_id),
  UNIQUE KEY uq_edge_mapping
    (run_id, input_version_id, output_version_id, relation_type, mapping_key),
  KEY ix_edge_downstream (team_id, project_id, input_version_id),
  KEY ix_edge_upstream (team_id, project_id, output_version_id),
  KEY ix_edge_run (run_id)
);

-- 8 源端 Outbox。需要与业务写入共事务时，应部署在实际业务事务范围内。
-- 不能因目录库里有 Outbox 就声称远程业务事务已经可靠。
-- 消费端仍需去重登记、payload hash 冲突检查、重试和对账。
CREATE TABLE meta_outbox (
  outbox_id VARCHAR(64) NOT NULL,
  event_source VARCHAR(160) NOT NULL,
  event_id VARCHAR(64) NOT NULL,
  event_type VARCHAR(128) NOT NULL,
  payload_json LONGTEXT NOT NULL,
  payload_hash CHAR(64) NOT NULL,
  delivery_state VARCHAR(32) NOT NULL,
  retry_count INT NOT NULL DEFAULT 0,
  next_attempt_at DATETIME(6) NOT NULL,
  lease_owner VARCHAR(128) NULL,
  lease_until DATETIME(6) NULL,
  last_error_ref VARCHAR(512) NULL,
  created_at DATETIME(6) NOT NULL,
  delivered_at DATETIME(6) NULL,
  PRIMARY KEY (outbox_id),
  UNIQUE KEY uq_event_identity (event_source, event_id),
  KEY ix_outbox_delivery (delivery_state, next_attempt_at)
);

-- 9 一次 Agent 请求的治理上下文。
CREATE TABLE meta_agent_run (
  agent_run_id VARCHAR(64) NOT NULL,
  request_id VARCHAR(128) NOT NULL,
  agent_id VARCHAR(128) NOT NULL,
  agent_version VARCHAR(128) NOT NULL,
  team_id VARCHAR(64) NOT NULL,
  project_id VARCHAR(64) NOT NULL,
  principal_ref VARCHAR(128) NOT NULL,
  policy_version VARCHAR(128) NOT NULL,
  prompt_ref VARCHAR(256) NOT NULL,
  model_ref VARCHAR(256) NOT NULL,
  tool_versions_json LONGTEXT NOT NULL,
  result_ref VARCHAR(512) NULL,
  status VARCHAR(32) NOT NULL,
  started_at DATETIME(6) NOT NULL,
  finished_at DATETIME(6) NULL,
  error_ref VARCHAR(512) NULL,
  PRIMARY KEY (agent_run_id),
  KEY ix_agent_scope_time (team_id, project_id, started_at),
  KEY ix_agent_request (request_id)
);

-- 10 Langfuse 等观测产品映射。不直接写观测产品的内部库。
CREATE TABLE meta_trace_ref (
  trace_ref_id VARCHAR(64) NOT NULL,
  agent_run_id VARCHAR(64) NOT NULL,
  provider VARCHAR(32) NOT NULL,
  provider_instance VARCHAR(64) NOT NULL,
  trace_id VARCHAR(128) NOT NULL,
  span_id VARCHAR(64) NOT NULL DEFAULT '',
  external_ref VARCHAR(1024) NULL,
  created_at DATETIME(6) NOT NULL,
  PRIMARY KEY (trace_ref_id),
  UNIQUE KEY uq_observation (provider_instance, trace_id, span_id),
  KEY ix_trace_agent (agent_run_id)
);

-- 11 实际业务证据。通过授权服务和源资产有效性校验后才返回给用户。
CREATE TABLE meta_evidence_ref (
  evidence_id VARCHAR(64) NOT NULL,
  agent_run_id VARCHAR(64) NOT NULL,
  processing_run_id VARCHAR(64) NOT NULL,
  asset_version_id VARCHAR(64) NOT NULL,
  evidence_type VARCHAR(32) NOT NULL,
  locator_json LONGTEXT NULL,
  read_at DATETIME(6) NOT NULL,
  data_snapshot_ref VARCHAR(512) NULL,
  index_manifest_ref VARCHAR(256) NULL,
  policy_version VARCHAR(128) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  PRIMARY KEY (evidence_id),
  KEY ix_evidence_agent (agent_run_id),
  KEY ix_evidence_source (asset_version_id),
  KEY ix_evidence_processing (processing_run_id)
);

-- 12 记忆内容版本的治理信息。正文放内容表或对象存储。
-- 一份新内容版本新建一行，审核状态按状态机变更并记审计事件。
CREATE TABLE meta_memory_item (
  asset_version_id VARCHAR(64) NOT NULL,
  memory_kind VARCHAR(32) NOT NULL,
  memory_content_ref VARCHAR(512) NOT NULL,
  origin_agent_run_id VARCHAR(64) NULL,
  feedback_ref VARCHAR(256) NULL,
  valid_scope_json LONGTEXT NOT NULL,
  review_state VARCHAR(32) NOT NULL,
  reviewed_by VARCHAR(128) NULL,
  reviewed_at DATETIME(6) NULL,
  expires_at DATETIME(6) NULL,
  supersedes_version_id VARCHAR(64) NULL,
  created_at DATETIME(6) NOT NULL,
  PRIMARY KEY (asset_version_id),
  KEY ix_memory_origin (origin_agent_run_id),
  KEY ix_memory_review (review_state, expires_at)
);
