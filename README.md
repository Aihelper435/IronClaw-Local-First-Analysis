# 🦀 IronClaw Local-First Analysis

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rust](https://img.shields.io/badge/rust-1.85%2B-orange.svg)](https://www.rust-lang.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15%2B-blue.svg)](https://www.postgresql.org/)

---

> ⚠️ **IMPORTANT NOTICE**
>
> **This is an experimental, community-maintained fork and is not officially supported by NEAR AI.**
>
> This repository contains experimental modifications to enable local-first operation of IronClaw. For the official, supported version of IronClaw, please visit the original repository:
>
> 🔗 **Official Repository:** [https://github.com/nearai/ironclaw](https://github.com/nearai/ironclaw)
>
> **⚠️ USE AT YOUR OWN RISK:** This fork is provided "as is" without warranty of any kind. The experimental modifications contained herein have not been reviewed or endorsed by the original maintainers. Users should exercise caution and understand that they are solely responsible for any consequences arising from the use of this fork.

---

> **Making IronClaw run locally without any cloud account**

This repository contains a comprehensive analysis of the [nearai/ironclaw](https://github.com/nearai/ironclaw) project, along with patches and documentation to enable local-first operation without requiring a NEAR AI cloud account.

---

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [What Was Done](#-what-was-done)
- [Key Findings](#-key-findings)
- [Quick Start](#-quick-start)
- [Patches](#-patches)
- [How to Apply Patches](#-how-to-apply-patches)
- [Documentation](#-documentation)
- [Features](#-features)
- [Requirements](#-requirements)
- [Contributing](#-contributing)

---

## 🎯 Project Overview

**IronClaw** is a Rust-based AI assistant developed by NEAR AI that defaults to using NEAR AI cloud services for LLM inference. This project analyzes IronClaw's cloud dependencies and provides patches to enable **local-first operation** - running the entire application on your machine without any cloud account.

### Why Local-First?

- 🔒 **Privacy**: Your conversations stay on your machine
- 💰 **Cost-Free**: No API costs after initial setup
- 🌐 **Offline Capable**: Works without internet connection
- ⚡ **Low Latency**: No network round-trips for inference
- 🎛️ **Full Control**: Choose your models and configurations

---

## ✅ What Was Done

### Analysis Performed

1. **Complete codebase review** of the nearai/ironclaw repository
2. **Identified all cloud dependencies** (NEAR AI authentication, model list fetching, etc.)
3. **Mapped the authentication flow** from startup to LLM request
4. **Discovered existing local alternatives** already supported in the codebase
5. **Created 5 patches** to improve the local-first experience
6. **Documented setup procedures** for various local LLM backends
7. **Assessed shipping readiness** of all patches

### Files in This Repository

```
├── README.md                          # This file
├── ironclaw_analysis.md               # Complete cloud dependency analysis
├── ironclaw_local_setup.md            # Step-by-step local setup guide
├── ironclaw_shipping_readiness.md     # Patch readiness assessment
├── ironclaw_patches/                  # Patch files
│   ├── 001-smart-default-backend.patch
│   ├── 002-skip-auth-check.patch
│   ├── 003-wizard-local-first.patch
│   ├── 004-env-example-local-first.patch
│   └── 005-embeddings-local-fallback.patch
└── ironclaw_project/                  # Modified IronClaw source (with patches applied)
```

---

## 🔍 Key Findings

### 🎉 Good News: IronClaw is Already Local-First Capable!

The codebase has **excellent abstraction** with support for multiple LLM backends:

| Backend | Cloud Required | Status |
|---------|----------------|--------|
| **NEAR AI** | ✅ Yes | Default backend |
| **Ollama** | ❌ No | Fully supported |
| **OpenAI-Compatible** | ❌ No | Fully supported (vLLM, LM Studio, LiteLLM) |
| **OpenAI** | ✅ Yes | Requires API key |
| **Anthropic** | ✅ Yes | Requires API key |

### The Patches Enhance UX, Not Functionality

Our patches don't add new functionality - they **improve discoverability** and **default behavior**:

- ✨ Auto-detect local Ollama installation
- ✨ Prioritize local options in setup wizard
- ✨ Better documentation in `.env.example`
- ✨ Skip cloud auth when using local backends (already works!)

### Minimal Code Changes Required

| Total Lines Changed | ~65 lines |
|---------------------|-----------|
| Breaking Changes | None |
| Backward Compatibility | ✅ Preserved |

---

## 🚀 Quick Start (Linux)

Run IronClaw locally in 5 minutes without any cloud account:

### Step 1: Install Ollama

```bash
# Install Ollama on Linux
curl -fsSL https://ollama.com/install.sh | sh

# Start the Ollama service
sudo systemctl start ollama
sudo systemctl enable ollama  # Optional: enable on boot
```

### Step 2: Pull a Model

```bash
ollama pull llama3.2
```

### Step 3: Set Up PostgreSQL with pgvector

```bash
# Debian/Ubuntu
sudo apt update
sudo apt install -y postgresql postgresql-contrib
sudo apt install -y postgresql-15-pgvector  # For PostgreSQL 15

# Fedora/RHEL
# sudo dnf install -y postgresql-server postgresql-contrib
# sudo dnf install -y pgvector_15  # For PostgreSQL 15

# Arch Linux
# sudo pacman -S postgresql
# yay -S pgvector  # From AUR

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql  # Optional: enable on boot

# Create database and enable pgvector
sudo -u postgres createdb ironclaw
sudo -u postgres psql ironclaw -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Create a user (optional, for easier access)
sudo -u postgres createuser --superuser $USER
```

### Step 4: Configure Environment

```bash
mkdir -p ~/.ironclaw
cat > ~/.ironclaw/.env << 'EOF'
LLM_BACKEND=ollama
OLLAMA_MODEL=llama3.2
DATABASE_URL=postgres://localhost/ironclaw
EOF
```

### Step 5: Install Rust (if not already installed)

```bash
# Install Rust using rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env  # Load Rust environment
```

### Step 6: Run IronClaw

```bash
cd ironclaw_project
cargo run -- --no-onboard
```

🎉 **That's it!** No NEAR AI account, no cloud API keys needed.

> **Note**: If using a different Linux distribution, package names and commands may vary. Refer to your distro's documentation for PostgreSQL and pgvector installation.

---

## 🩹 Patches

### Patch Overview

| # | Name | File | Description | Status |
|---|------|------|-------------|--------|
| 001 | Smart Default Backend | `src/config/llm.rs` | Auto-detect Ollama/local servers | ✅ Applied |
| 002 | Skip Auth Check | `src/main.rs` | Document existing auth skip behavior | ✅ No changes needed |
| 003 | Wizard Local-First | `src/setup/wizard.rs` | Prioritize local options in setup | ✅ Applied |
| 004 | Env Example | `.env.example` | Add local-first documentation | ✅ Applied |
| 005 | Embeddings Fallback | `src/config/embeddings.rs` | Auto-detect local embeddings | ⚠️ Future enhancement |

---

### 📄 Patch 001: Smart Default Backend Selection

**Purpose**: Automatically detect and use local LLM servers if available.

**Logic**:
1. If `LLM_BASE_URL` is set → Use `openai_compatible` backend
2. If Ollama is running on localhost:11434 → Use `ollama` backend
3. Otherwise → Fall back to `nearai` (original behavior)

**Key Code**:
```rust
fn is_ollama_available() -> bool {
    use std::net::TcpStream;
    use std::time::Duration;
    
    TcpStream::connect_timeout(
        &"127.0.0.1:11434".parse().unwrap(),
        Duration::from_millis(100)
    ).is_ok()
}
```

---

### 📄 Patch 002: Skip Auth Check (Documentation Only)

**Purpose**: Document that local backends already skip NEAR AI authentication.

**Existing Code** (no changes needed):
```rust
// In src/main.rs
if config.llm.backend == LlmBackend::NearAi && config.llm.nearai.api_key.is_none() {
    session.ensure_authenticated().await?;
}
```

This condition ensures authentication is **only required for NEAR AI backend**.

---

### 📄 Patch 003: Wizard Local-First UX

**Purpose**: Reorder the setup wizard to show local options first.

**New Menu Order**:
```
Select inference provider:
  > 1. Ollama (local)
    2. OpenAI-compatible (local/self-hosted)
    ────────────── Cloud Options ──────────────
    3. NEAR AI (cloud, free tier)
    4. Anthropic (cloud, requires key)
    5. OpenAI (cloud, requires key)
```

---

### 📄 Patch 004: Enhanced .env.example

**Purpose**: Add a comprehensive local-first quick start guide to the environment template.

**Added Content**:
```env
# ===========================================
# LOCAL-FIRST QUICK START
# ===========================================
#
# Run IronClaw without any cloud account:
#
# OPTION 1: Ollama (Recommended)
#   1. Install: curl -fsSL https://ollama.com/install.sh | sh
#   2. Pull model: ollama pull llama3.2
#   3. Uncomment below:
#
# LLM_BACKEND=ollama
# OLLAMA_MODEL=llama3.2
#
# OPTION 2: LM Studio / vLLM / LiteLLM
#   LLM_BACKEND=openai_compatible
#   LLM_BASE_URL=http://localhost:1234/v1
#   LLM_MODEL=your-model-name
```

---

### 📄 Patch 005: Embeddings Local Fallback (Future)

**Purpose**: Auto-configure local embeddings when using local LLM backend.

**Status**: ⚠️ Not applied - requires architectural changes.

**Workaround**: Manually set `EMBEDDING_PROVIDER=ollama` in your `.env` file.

---

## 🔧 How to Apply Patches

### Option A: Use the Pre-Patched Project

The `ironclaw_project/` directory already has patches 001, 003, and 004 applied:

```bash
cd ironclaw_project
cargo run -- --no-onboard
```

### Option B: Apply Patches to Fresh Clone

```bash
# Clone the original repository
git clone https://github.com/nearai/ironclaw.git
cd ironclaw

# Apply patches
git apply ../ironclaw_patches/001-smart-default-backend.patch
git apply ../ironclaw_patches/003-wizard-local-first.patch
git apply ../ironclaw_patches/004-env-example-local-first.patch
```

### Option C: Manual Configuration (No Patches)

You can run locally **without any patches**:

```bash
# Set environment variables
export LLM_BACKEND=ollama
export OLLAMA_MODEL=llama3.2
export DATABASE_URL=postgres://localhost/ironclaw

# Skip the setup wizard
cargo run -- --no-onboard
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [ironclaw_analysis.md](./ironclaw_analysis.md) | Complete cloud dependency analysis |
| [ironclaw_local_setup.md](./ironclaw_local_setup.md) | Step-by-step local setup guide |
| [ironclaw_shipping_readiness.md](./ironclaw_shipping_readiness.md) | Patch readiness assessment |

---

## ⚙️ Features

### ✅ Works Locally

| Feature | Status |
|---------|--------|
| Interactive REPL | ✅ Full support |
| Multi-turn conversations | ✅ Full support |
| Tool calling | ✅ Full support |
| Memory/workspace | ✅ Full support |
| HTTP webhooks | ✅ Full support |
| Telegram bot | ✅ Full support |
| WASM extensions | ✅ Full support |
| Routines/scheduling | ✅ Full support |
| Docker sandbox | ✅ Full support |

### ⚠️ Limited Locally

| Feature | Limitation |
|---------|------------|
| Model switching | Requires restart |
| Cost tracking | No pricing data |
| Model discovery | Static model list |

---

## 📦 Requirements

### Minimum Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| **Rust** | 1.85+ | [Install](https://rustup.rs) |
| **PostgreSQL** | 15+ | With pgvector extension |
| **Ollama** | Latest | Or any OpenAI-compatible server |

### Hardware Requirements

| Model Size | RAM | GPU VRAM |
|------------|-----|----------|
| 3B-7B | 8GB+ | 8GB+ |
| 8B-13B | 16GB+ | 16GB+ |
| 30B-70B | 64GB+ | 48GB+ |

### Supported LLM Backends

| Backend | URL | Notes |
|---------|-----|-------|
| **Ollama** | [ollama.com](https://ollama.com) | Easiest setup |
| **LM Studio** | [lmstudio.ai](https://lmstudio.ai) | GUI-based |
| **vLLM** | [vllm.ai](https://vllm.ai) | High-performance |
| **LiteLLM** | [litellm.ai](https://litellm.ai) | Proxy for multiple backends |

---

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Reporting Issues

- 🐛 Found a bug? [Open an issue](https://github.com/Aihelper435/Localfirst-/issues)
- 💡 Have a suggestion? [Start a discussion](https://github.com/Aihelper435/Localfirst-/discussions)

### Contributing Code

1. Fork this repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -am 'Add my feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Open a Pull Request

### Areas for Contribution

- [ ] Implement Patch 005 (embeddings auto-fallback)
- [ ] Add automated tests for local backend detection
- [ ] Create Docker Compose for easy deployment
- [ ] Add support for more LLM backends
- [ ] Improve documentation

---

## 📄 License

This analysis and patches are provided under the MIT License. The original IronClaw project has its own license - please refer to [nearai/ironclaw](https://github.com/nearai/ironclaw) for details.

---

## 🙏 Acknowledgments

- [NEAR AI](https://near.ai) - For creating IronClaw
- [Ollama](https://ollama.com) - For making local LLMs accessible
- [pgvector](https://github.com/pgvector/pgvector) - For vector database support

---

<div align="center">

**Made with ❤️ for the local-first community**

[⬆ Back to Top](#-ironclaw-local-first-analysis)

</div>
