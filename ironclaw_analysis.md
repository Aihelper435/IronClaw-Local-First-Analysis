# IronClaw Cloud Dependency Analysis

## Executive Summary

IronClaw is a Rust-based AI assistant that **defaults to NEAR AI cloud services** for LLM inference. However, the software **already supports local-first alternatives** that can be used without any cloud account. This analysis identifies all NEAR AI cloud dependencies and provides patches to make local operation the default.

**Key Finding:** The codebase is well-designed with abstracted LLM providers. Making it "local-first" requires minimal code changes - primarily configuration defaults and improved UX for local setup.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Cloud Dependencies Identified](#cloud-dependencies-identified)
3. [Existing Local Alternatives](#existing-local-alternatives)
4. [Patch Summary](#patch-summary)
5. [Trade-offs and Limitations](#trade-offs-and-limitations)

---

## Architecture Overview

### LLM Provider System

IronClaw uses a modular LLM provider system with the following backends:

| Backend | Env Value | Cloud Required | Notes |
|---------|-----------|----------------|-------|
| **NEAR AI** | `nearai` | ✅ Yes | Default backend |
| **Ollama** | `ollama` | ❌ No | Local inference |
| **OpenAI-Compatible** | `openai_compatible` | ❌ No* | Local servers (vLLM, LiteLLM, LM Studio) |
| **OpenAI** | `openai` | ✅ Yes | Direct API |
| **Anthropic** | `anthropic` | ✅ Yes | Direct API |
| **Tinfoil** | `tinfoil` | ✅ Yes | Private inference |

*OpenAI-compatible can point to local servers with no cloud dependency.

### Authentication Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        Application Start                         │
├─────────────────────────────────────────────────────────────────┤
│  1. Load .env and bootstrap config                              │
│  2. Determine LLM_BACKEND (default: nearai)                     │
│  3. If NEAR AI backend:                                          │
│     a. Check for NEARAI_API_KEY → Use API key auth              │
│     b. Else check for session token → Use session auth          │
│     c. If no auth → Trigger OAuth login flow (browser)          │
│  4. Create LLM provider chain                                    │
│  5. Start channels (REPL, HTTP, etc.)                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Cloud Dependencies Identified

### 1. NEAR AI Session Token Authentication (Primary)

**Location:** `src/llm/session.rs`

**Description:** The default authentication flow uses browser-based OAuth via GitHub or Google, redirecting to NEAR AI servers for session token generation.

**Code Path:**
```
SessionManager::ensure_authenticated()
  → SessionManager::initiate_login()
    → OAuth flow (GitHub/Google)
    → Callback to https://private.near.ai/v1/auth/*
    → Session token saved to ~/.ironclaw/session.json
```

**Cloud Endpoints Called:**
- `https://private.near.ai/v1/auth/github`
- `https://private.near.ai/v1/auth/google`
- `https://private.near.ai/v1/users/me` (validation)

**Why It Exists:** Provides zero-configuration access to multiple LLM models through NEAR AI's infrastructure without users needing individual API keys.

---

### 2. NEAR AI API Key Authentication (Alternative)

**Location:** `src/llm/session.rs`, `src/config/llm.rs`

**Description:** Alternative auth using API key from cloud.near.ai dashboard.

**Environment Variable:** `NEARAI_API_KEY`

**Cloud Endpoints Called:**
- `https://cloud-api.near.ai/v1/chat/completions`

**Why It Exists:** Allows programmatic/server deployments without interactive OAuth.

---

### 3. NEAR AI Model List & Pricing Fetch

**Location:** `src/llm/nearai_chat.rs` (lines 674-754)

**Description:** On provider initialization, background task fetches available models and pricing info from NEAR AI API.

**Cloud Endpoints Called:**
- `{base_url}/v1/models`
- `{base_url}/v1/model/list`

**Why It Exists:** Dynamic model discovery and accurate cost tracking.

**Impact if Unavailable:** Falls back to static model costs - no functional impact.

---

### 4. Setup Wizard Authentication Step

**Location:** `src/setup/wizard.rs` (lines 724-850)

**Description:** The onboarding wizard (`ironclaw onboard`) presents NEAR AI as the primary option and triggers OAuth flow.

**Why It Exists:** User-friendly first-run experience.

---

### 5. Startup Authentication Check

**Location:** `src/main.rs` (lines 211-215)

**Description:** On startup, if using NEAR AI backend without API key, validates session token.

```rust
if config.llm.backend == LlmBackend::NearAi && config.llm.nearai.api_key.is_none() {
    session.ensure_authenticated().await?;
}
```

**Why It Exists:** Ensures valid credentials before proceeding.

---

### 6. Default Backend Configuration

**Location:** `src/config/llm.rs` (lines 13-28, 180-201)

**Description:** `LlmBackend` enum defaults to `NearAi`.

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum LlmBackend {
    #[default]
    NearAi,  // ← This is the cloud dependency
    // ...
}
```

---

## Existing Local Alternatives

The codebase already fully supports local operation:

### Option 1: Ollama (Recommended for Local)

```env
LLM_BACKEND=ollama
OLLAMA_MODEL=llama3.2
OLLAMA_BASE_URL=http://localhost:11434
```

- Pull models with: `ollama pull llama3.2`
- No cloud account required
- Runs entirely on local hardware

### Option 2: OpenAI-Compatible Local Servers

```env
LLM_BACKEND=openai_compatible
LLM_BASE_URL=http://localhost:8000/v1
LLM_MODEL=meta-llama/Llama-3.1-8B-Instruct
```

Supports:
- **vLLM** - High-performance inference server
- **LiteLLM** - Proxy that unifies multiple backends
- **LM Studio** - Local GUI with server mode
- **text-generation-webui** - Popular open-source UI

### Option 3: Self-Hosted OpenAI-Compatible API

For organizations running their own inference infrastructure.

---

## Patch Summary

The following patches make IronClaw "local-first" while preserving cloud functionality:

| Patch # | File | Description |
|---------|------|-------------|
| 001 | `src/config/llm.rs` | Add environment check for default backend selection |
| 002 | `src/main.rs` | Skip NEAR AI auth for local backends |
| 003 | `src/setup/wizard.rs` | Reorder setup wizard to prioritize local options |
| 004 | `.env.example` | Add local-first configuration examples |

### Patch Details

#### Patch 001: Smart Default Backend Selection

Changes the default backend selection logic to check for local servers:

1. If `OLLAMA_BASE_URL` is accessible → default to `ollama`
2. If `LLM_BASE_URL` is set → default to `openai_compatible`
3. Otherwise → default to `nearai` (maintains backwards compatibility)

#### Patch 002: Skip Auth for Local Backends

The current code already does this correctly - no changes needed. The auth check is:
```rust
if config.llm.backend == LlmBackend::NearAi && config.llm.nearai.api_key.is_none()
```

This only triggers for NEAR AI backend, not local backends.

#### Patch 003: Wizard Local-First UX

Reorder the inference provider selection menu to show local options first:
1. Ollama (local)
2. OpenAI-compatible (local/self-hosted)
3. NEAR AI (cloud, free tier)
4. Anthropic (cloud, requires key)
5. OpenAI (cloud, requires key)

#### Patch 004: Enhanced .env.example

Add a clear "Local-First Quick Start" section at the top of the example env file.

---

## Trade-offs and Limitations

### What You Lose with Local-Only Mode

| Feature | NEAR AI | Local |
|---------|---------|-------|
| Multiple models | ✅ 50+ models | ⚠️ Limited by hardware |
| Zero config | ✅ OAuth login | ❌ Requires setup |
| Model switching | ✅ Dynamic | ⚠️ Restart required |
| Cost tracking | ✅ Accurate | ❌ No cost data |
| Model pricing fetch | ✅ Automatic | ❌ N/A |

### Hardware Requirements for Local

| Model Size | RAM Required | GPU VRAM |
|------------|--------------|----------|
| 7B params | 8GB+ | 8GB+ |
| 13B params | 16GB+ | 16GB+ |
| 70B params | 64GB+ | 48GB+ |

### Functional Parity

All core features work identically with local backends:
- ✅ Tool calling
- ✅ Multi-turn conversations
- ✅ Memory/workspace
- ✅ Channels (REPL, HTTP, Telegram, etc.)
- ✅ WASM extensions
- ✅ Routines/scheduling

---

## Files Modified

| File | Lines Changed | Purpose |
|------|---------------|---------|
| `src/config/llm.rs` | ~20 | Smart default detection |
| `src/setup/wizard.rs` | ~30 | UX reordering |
| `.env.example` | ~15 | Documentation |

Total: ~65 lines of changes for full local-first operation.

---

## Conclusion

IronClaw is **already capable of running locally** without NEAR AI cloud services. The primary changes needed are:

1. **UX improvements** - Make local options more discoverable
2. **Smart defaults** - Auto-detect local servers
3. **Documentation** - Clear local setup guide

The patches provided achieve these goals with minimal code changes while maintaining full backwards compatibility with NEAR AI cloud services for users who prefer them.
