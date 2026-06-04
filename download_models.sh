#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════
# VoIP Lab - Model Download Script
# Downloads STT, TTS, and LLM models for local AI inference
# ═══════════════════════════════════════════════════════════════════════════

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Model directories
MODELS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ava/models"
STT_DIR="$MODELS_DIR/stt"
TTS_DIR="$MODELS_DIR/tts"
LLM_DIR="$MODELS_DIR/llm"

# Model URLs
VOSK_URL="https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"
PIPER_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx"
TINYLLAMA_URL="https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"

# Model files
VOSK_FILE="$STT_DIR/vosk-model-small-en-us-0.15.zip"
VOSK_EXTRACTED="$STT_DIR/vosk-model-small-en-us-0.15"
PIPER_FILE="$TTS_DIR/en_US-lessac-medium.onnx"
TINYLLAMA_FILE="$LLM_DIR/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"

echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}VoIP Lab - Downloading AI Models${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Models directory: $MODELS_DIR"
echo ""

# Create directories
mkdir -p "$STT_DIR" "$TTS_DIR" "$LLM_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# Download Vosk STT Model
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[1/3] Vosk STT Model${NC}"

if [ -d "$VOSK_EXTRACTED" ]; then
    echo -e "${GREEN}✓ Vosk model already extracted at: $VOSK_EXTRACTED${NC}"
else
    if [ -f "$VOSK_FILE" ]; then
        echo -e "${YELLOW}→ Vosk ZIP found, extracting...${NC}"
    else
        echo -e "${YELLOW}→ Downloading Vosk model (60MB)...${NC}"
        if ! curl -L -o "$VOSK_FILE" "$VOSK_URL"; then
            echo -e "${RED}✗ Failed to download Vosk model${NC}"
            exit 1
        fi
    fi
    
    echo -e "${YELLOW}→ Extracting Vosk model...${NC}"
    unzip -q "$VOSK_FILE" -d "$STT_DIR"
    echo -e "${GREEN}✓ Vosk model downloaded and extracted${NC}"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Download Piper TTS Model
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[2/3] Piper TTS Model${NC}"

if [ -f "$PIPER_FILE" ]; then
    echo -e "${GREEN}✓ Piper model already exists at: $PIPER_FILE${NC}"
else
    echo -e "${YELLOW}→ Downloading Piper TTS model (150MB)...${NC}"
    if ! curl -L -o "$PIPER_FILE" "$PIPER_URL"; then
        echo -e "${RED}✗ Failed to download Piper model${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Piper TTS model downloaded${NC}"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Download TinyLlama LLM Model
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[3/3] TinyLlama LLM Model${NC}"

if [ -f "$TINYLLAMA_FILE" ]; then
    echo -e "${GREEN}✓ TinyLlama model already exists at: $TINYLLAMA_FILE${NC}"
else
    echo -e "${YELLOW}→ Downloading TinyLlama LLM model (730MB)...${NC}"
    if ! curl -L -o "$TINYLLAMA_FILE" "$TINYLLAMA_URL"; then
        echo -e "${RED}✗ Failed to download TinyLlama model${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ TinyLlama LLM model downloaded${NC}"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ All models downloaded successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Model sizes:"
du -sh "$STT_DIR" "$TTS_DIR" "$LLM_DIR" 2>/dev/null || true
echo ""
echo "Ready to start with: docker compose up -d"
echo ""
