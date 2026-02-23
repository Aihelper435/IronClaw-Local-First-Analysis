# IronClaw Local-First Setup Guide

This guide explains how to run IronClaw **entirely locally** without any NEAR AI cloud account or other cloud services.

---

## Table of Contents

1. [Quick Start (TL;DR)](#quick-start-tldr)
2. [Prerequisites](#prerequisites)
3. [Option 1: Ollama (Recommended)](#option-1-ollama-recommended)
4. [Option 2: LM Studio](#option-2-lm-studio)
5. [Option 3: vLLM (Advanced)](#option-3-vllm-advanced)
6. [Option 4: LiteLLM Proxy](#option-4-litellm-proxy)
7. [Database Setup](#database-setup)
8. [Applying the Patches](#applying-the-patches)
9. [Running IronClaw](#running-ironclaw)
10. [Troubleshooting](#troubleshooting)

---

## Quick Start (TL;DR)

```bash
# 1. Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# 2. Pull a model
ollama pull llama3.2

# 3. Create ~/.ironclaw/.env
mkdir -p ~/.ironclaw
cat > ~/.ironclaw/.env << 'EOF'
LLM_BACKEND=ollama
OLLAMA_MODEL=llama3.2
DATABASE_URL=postgres://localhost/ironclaw
EOF

# 4. Setup database
createdb ironclaw
psql ironclaw -c "CREATE EXTENSION IF NOT EXISTS vector;"

# 5. Run IronClaw (skip auth)
cd /path/to/ironclaw
cargo run -- --no-onboard
```

That's it! No cloud account needed.

---

## Prerequisites

### Required
- **Rust 1.85+** - [Install](https://rustup.rs)
- **PostgreSQL 15+** with pgvector - [Install](https://www.postgresql.org/download/)
- **One of the following LLM backends:**
  - Ollama (easiest)
  - LM Studio (GUI)
  - vLLM (advanced)
  - Any OpenAI-compatible server

### Hardware Requirements

| Model Size | Minimum RAM | Recommended |
|------------|-------------|-------------|
| 3B-7B | 8GB | 16GB |
| 8B-13B | 16GB | 32GB |
| 30B-70B | 64GB | 128GB + GPU |

For GPU acceleration:
- NVIDIA: CUDA 11.8+ with 8GB+ VRAM
- AMD: ROCm 5.6+ with 8GB+ VRAM
- Apple Silicon: Metal (built into macOS)

---

## Option 1: Ollama (Recommended)

Ollama is the easiest way to run LLMs locally.

### Installation

**macOS/Linux:**
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

**Windows:**
Download from [ollama.com](https://ollama.com/download)

### Pull a Model

```bash
# Recommended models
ollama pull llama3.2        # 3B, fast, good for most tasks
ollama pull llama3.1:8b     # 8B, better quality
ollama pull codellama       # Code-focused
ollama pull mistral         # Good general purpose
```

### Configure IronClaw

Create `~/.ironclaw/.env`:
```env
LLM_BACKEND=ollama
OLLAMA_MODEL=llama3.2
OLLAMA_BASE_URL=http://localhost:11434

# Database
DATABASE_URL=postgres://localhost/ironclaw
```

### Verify Ollama is Running

```bash
curl http://localhost:11434/api/tags
# Should return list of installed models
```

---

## Option 2: LM Studio

LM Studio provides a GUI for downloading and running models.

### Installation

1. Download from [lmstudio.ai](https://lmstudio.ai)
2. Install and launch
3. Download a model from the built-in browser (e.g., search "llama 3.2")
4. Go to "Local Server" tab and click "Start Server"

### Configure IronClaw

```env
LLM_BACKEND=openai_compatible
LLM_BASE_URL=http://localhost:1234/v1
LLM_MODEL=llama-3.2-3b-instruct
# LLM_API_KEY not needed for LM Studio

DATABASE_URL=postgres://localhost/ironclaw
```

---

## Option 3: vLLM (Advanced)

vLLM is a high-performance inference engine, ideal for GPU servers.

### Installation

```bash
pip install vllm
```

### Start the Server

```bash
# Basic usage
python -m vllm.entrypoints.openai.api_server \
    --model meta-llama/Llama-3.1-8B-Instruct \
    --port 8000

# With more options
python -m vllm.entrypoints.openai.api_server \
    --model meta-llama/Llama-3.1-8B-Instruct \
    --port 8000 \
    --tensor-parallel-size 2 \
    --max-model-len 8192
```

### Configure IronClaw

```env
LLM_BACKEND=openai_compatible
LLM_BASE_URL=http://localhost:8000/v1
LLM_MODEL=meta-llama/Llama-3.1-8B-Instruct
LLM_API_KEY=not-needed

DATABASE_URL=postgres://localhost/ironclaw
```

---

## Option 4: LiteLLM Proxy

LiteLLM unifies multiple backends behind a single API.

### Installation

```bash
pip install litellm[proxy]
```

### Create Config

`litellm_config.yaml`:
```yaml
model_list:
  - model_name: gpt-3.5-turbo
    litellm_params:
      model: ollama/llama3.2
      api_base: http://localhost:11434

  - model_name: claude-3-sonnet
    litellm_params:
      model: ollama/mistral
      api_base: http://localhost:11434
```

### Start the Proxy

```bash
litellm --config litellm_config.yaml --port 4000
```

### Configure IronClaw

```env
LLM_BACKEND=openai_compatible
LLM_BASE_URL=http://localhost:4000/v1
LLM_MODEL=gpt-3.5-turbo
LLM_API_KEY=not-needed

DATABASE_URL=postgres://localhost/ironclaw
```

---

## Database Setup

IronClaw requires PostgreSQL with the pgvector extension.

### Install PostgreSQL

**macOS:**
```bash
brew install postgresql@15 pgvector
brew services start postgresql@15
```

**Ubuntu/Debian:**
```bash
sudo apt install postgresql postgresql-contrib
# For pgvector, see: https://github.com/pgvector/pgvector#installation
```

### Create Database

```bash
# Create the database
createdb ironclaw

# Enable pgvector extension
psql ironclaw -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

### Verify

```bash
psql ironclaw -c "SELECT extname FROM pg_extension WHERE extname = 'vector';"
# Should output: vector
```

---

## Applying the Patches

The patches in `~/ironclaw_patches/` make local operation the default.

### Manual Application

The patches are conceptual and should be applied manually:

1. **Patch 001** (Smart default backend): Modify `src/config/llm.rs` to auto-detect Ollama
2. **Patch 002** (Skip auth): No changes needed - already works correctly
3. **Patch 003** (Wizard UX): Modify `src/setup/wizard.rs` to show local options first
4. **Patch 004** (.env.example): Add local-first section to `.env.example`
5. **Patch 005** (Embeddings): Modify embeddings config for local fallback

### Without Patches

You can run locally **without any patches** by simply:

1. Setting `LLM_BACKEND=ollama` (or `openai_compatible`)
2. Using `--no-onboard` flag to skip the setup wizard
3. Ensuring your LLM server is running before starting IronClaw

---

## Running IronClaw

### First Run (Skip Onboard Wizard)

```bash
cd /path/to/ironclaw
cargo run -- --no-onboard
```

### Normal Run

```bash
cargo run
```

### With Debug Logging

```bash
RUST_LOG=ironclaw=debug cargo run
```

### Single Message Mode

```bash
cargo run -- -m "Hello, what can you do?"
```

---

## Troubleshooting

### "Connection refused" to Ollama

```bash
# Check if Ollama is running
pgrep -f ollama

# Start Ollama service
ollama serve
```

### "Missing required setting 'DATABASE_URL'"

```bash
# Create the .env file
mkdir -p ~/.ironclaw
echo "DATABASE_URL=postgres://localhost/ironclaw" >> ~/.ironclaw/.env
```

### "NEAR AI authentication required"

You're still using the default backend. Set `LLM_BACKEND`:

```bash
echo "LLM_BACKEND=ollama" >> ~/.ironclaw/.env
```

### Slow Response Times

- Use a smaller model (3B-7B)
- Enable GPU acceleration (install CUDA/ROCm drivers)
- Reduce `max_tokens` in requests

### Out of Memory

- Use a quantized model (Q4_K_M)
- Reduce context length (`--max-model-len` for vLLM)
- Use a smaller model

### pgvector Extension Error

```bash
# Install pgvector from source
git clone https://github.com/pgvector/pgvector.git
cd pgvector
make
sudo make install

# Then enable in database
psql ironclaw -c "CREATE EXTENSION vector;"
```

---

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `LLM_BACKEND` | `nearai` | Set to `ollama` or `openai_compatible` for local |
| `OLLAMA_MODEL` | `llama3` | Model name for Ollama |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama server URL |
| `LLM_BASE_URL` | - | Base URL for openai_compatible |
| `LLM_MODEL` | `default` | Model for openai_compatible |
| `LLM_API_KEY` | - | Optional API key |
| `DATABASE_URL` | - | PostgreSQL connection string |

---

## What Works Locally

All core features work with local LLM backends:

- ✅ Interactive REPL
- ✅ Multi-turn conversations
- ✅ Tool calling
- ✅ Memory/workspace
- ✅ HTTP webhooks
- ✅ Telegram bot
- ✅ WASM extensions
- ✅ Routines/scheduling
- ✅ Docker sandbox

## What's Limited Locally

- ⚠️ Model switching (requires restart)
- ⚠️ Cost tracking (no pricing data)
- ⚠️ Model discovery (hardcoded list)
- ⚠️ Some models may not support all tool calling features

---

## Summary

Running IronClaw locally is straightforward:

1. Install Ollama and pull a model
2. Set `LLM_BACKEND=ollama` in your `.env`
3. Setup PostgreSQL with pgvector
4. Run with `cargo run -- --no-onboard`

No NEAR AI account, no cloud API keys, complete privacy! 🔒
