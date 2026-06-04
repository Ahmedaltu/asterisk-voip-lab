# asterisk-voip-lab

AI-powered VoIP lab for WSL2 with Docker. Runs Asterisk PBX + AVA AI engine on a local bridge network using RTP/ExternalMedia.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│ WSL2 Docker Desktop - Bridge Network: "voip"                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Zoiper/Linphone ──SIP──> Kamailio ──SIP──> Asterisk ──ARI──> AVA  │
│  (host:5060)      :5060   (container)  :5061 (container) :8088     │
│                                  │                           │      │
│                                  └─────RTP/UDP:18080────────┘      │
│                                                                     │
│  AVA  ────────WebSocket:8765────> local_ai_server                  │
│        (Vosk STT + TinyLlama LLM + Piper TTS)                       │
│                                                                     │
│  Prometheus :9091 ──> Grafana :3001                                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

Container DNS (127.0.0.11:53) resolves hostnames:
  asterisk          → 172.17.x.x
  ai_engine         → 172.17.x.y
  local_ai_server   → 172.17.x.z
```

## Stack

- **Kamailio** — SIP proxy, accepts calls from clients on port 5060
- **Asterisk** — PBX, routes to AI engine via ARI on port 8088
- **AVA ai_engine** — Python asyncio daemon, receives RTP on port 18080 (ExternalMedia)
- **local_ai_server** — WebSocket AI server: Vosk (STT) + TinyLlama (LLM) + Piper (TTS)
- **SIP.js widget** — Browser softphone
- **Grafana + Prometheus** — Monitoring & metrics

## Services & Ports

| Service | Container | Port | Purpose |
|---------|-----------|------|---------|
| **kamailio** | voip network | 5060 (UDP/TCP) | SIP proxy, public entry point |
| **asterisk** | voip network | 5061 (SIP), 8088 (ARI) | PBX, AI routing |
| **ai_engine** | voip network | 18080 (RTP), 15000 (metrics) | AVA AI brain, ExternalMedia RTP |
| **local_ai_server** | voip network | 8765 (WebSocket) | STT + LLM + TTS models |
| **widget** | voip network | 3000 | Browser SIP.js client |
| **grafana** | voip network | 3001 | Dashboards |
| **prometheus** | voip network | 9091 | Metrics scraper |

## Quick Start

### 1. Download AI Models (~1GB total)

```bash
chmod +x download_models.sh
./download_models.sh
```

Models downloaded to:
- `ava/models/stt/vosk-model-small-en-us-0.15/` (60MB)
- `ava/models/tts/en_US-lessac-medium.onnx` (150MB)
- `ava/models/llm/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf` (730MB)

### 2. Build & Start Stack

```bash
# Build Docker images
docker compose build

# Start all services (in dependency order)
docker compose up -d

# Verify all containers running
docker compose ps
```

### 3. Verify Connectivity

```bash
# Test Asterisk ARI from ai_engine
docker compose exec ai_engine \
  curl -u ava:ava-secret http://asterisk:8088/ari/channels

# Test local_ai_server WebSocket
docker compose exec ai_engine python3 << 'EOF'
import asyncio, websockets, json
async def test():
    async with websockets.connect('ws://local_ai_server:8765') as ws:
        await ws.send(json.dumps({'type': 'status'}))
        print(await ws.recv())
asyncio.run(test())
EOF

# Check RTP port listening on ai_engine
docker compose exec ai_engine netstat -tlnup | grep 18080
```

### 4. Make Test Calls

**Browser Widget:** http://localhost:3000
- Register as: `browser` / `passbrowser`
- Dial `200` to reach AI agent

**Zoiper/Linphone:** 
- Server: `localhost:5061` (Asterisk)
- User: `101` / `pass101` or `102` / `pass102`
- Dial `200` for AI agent
- Dial `300` for echo test

### 5. Monitor

**Grafana:** http://localhost:3001 (admin / changeme)
**Prometheus:** http://localhost:9091

## Network Configuration

### Docker Compose Bridge Network

All services run on the `voip` bridge network (not host network). This allows:
- Container-to-container DNS resolution via `127.0.0.11:53`
- Asterisk sends RTP UDP packets to `ai_engine` hostname
- AI engine connects to `local_ai_server` via hostname
- Port mappings only for host → container direction

### Environment Variables

**Root [.env](.env):**
- `ASTERISK_HOST=asterisk` — Asterisk container hostname
- `LOCAL_WS_URL=ws://local_ai_server:8765` — AI server endpoint
- `LOCAL_WS_AUTH_TOKEN=voiplab-secret-token` — WebSocket auth
- Model paths and SIP passwords

**[ava/.env](ava/.env):**
- `ASTERISK_ARI_USERNAME=ava`, `ASTERISK_ARI_PASSWORD=ava-secret`
- `LOCAL_AI_MODE=full` — Enable STT, LLM, TTS
- Mirrors root `.env` for container build

### RTP/ExternalMedia Config

**[ava/config/ai-agent.yaml](ava/config/ai-agent.yaml):**
```yaml
external_media:
  rtp_host: 0.0.0.0      # Listen on all interfaces
  rtp_port: 18080        # Expose with port mapping
  advertise_host: ai_engine  # Tell Asterisk to send RTP here
  allowed_remote_hosts:
    - asterisk             # Only accept from Asterisk container
```

**[services/pbx/configs/extensions.conf](services/pbx/configs/extensions.conf):**
```
exten => 200,1,Set(AI_CONTEXT=default)
exten => 200,n,Stasis(asterisk-ai-voice-agent)  # Route to AVA via ARI
exten => 200,n,Hangup()
```

## Troubleshooting

### Models Not Found

```bash
./download_models.sh
docker compose up -d local_ai_server
docker compose logs local_ai_server
```

### Asterisk Cannot Reach AI Engine

```bash
# Verify RTP port is listening
docker compose exec ai_engine netstat -tlnup | grep 18080

# Test DNS resolution
docker compose exec asterisk nslookup ai_engine 127.0.0.11

# Check ai_engine logs for RTP errors
docker compose logs ai_engine | grep -i rtp
```

### Local AI Server WebSocket Connection Fails

```bash
# Test auth token
docker compose exec ai_engine python3 << 'EOF'
import asyncio, websockets, json
async def test():
    async with websockets.connect('ws://local_ai_server:8765') as ws:
        token = 'voiplab-secret-token'
        await ws.send(json.dumps({'type': 'auth', 'auth_token': token}))
        print(await ws.recv())
asyncio.run(test())
EOF
```

### View Real-Time Logs

```bash
docker compose logs -f asterisk           # Asterisk debug logs
docker compose logs -f ai_engine          # AVA engine
docker compose logs -f local_ai_server    # AI models
```

### SSH into Containers

```bash
docker compose exec asterisk bash
docker compose exec ai_engine bash
docker compose exec local_ai_server bash
```

## Stop & Cleanup

```bash
# Stop all services (keep volumes)
docker compose down

# Remove everything including volumes
docker compose down -v

# Rebuild single service
docker compose build ai_engine
docker compose up -d ai_engine
```
