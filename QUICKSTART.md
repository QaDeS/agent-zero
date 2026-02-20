# Quick Start - Agent Zero with Model Overrides

## 🚀 Fastest Way to Run

### 1. Build the Image

```bash
./run-local.sh build
```

### 2. Run with Docker Compose

```bash
./run-local.sh compose
```

### 3. Access the UI

Open http://localhost:50080 in your browser.

---

## 👤 Running as a Different User

### Method 1: Using `sudo`

```bash
# Create data directory for the other user
sudo mkdir -p /home/otheruser/a0-data
sudo chown -R otheruser:otheruser /home/otheruser/a0-data

# Run as that user
sudo -u otheruser ./run-local.sh compose
```

### Method 2: Using Docker Compose directly

```bash
# Switch to the user
su - otheruser

# Run
cd /path/to/agent-zero
docker-compose -f docker-compose.local.yml up -d
```

### Method 3: Using Podman (Rootless by Default)

```bash
# As any user (no sudo needed):
podman build -f Dockerfile.localdev -t agent-zero:model-overrides .
podman-compose -f docker-compose.local.yml up -d
```

---

## 📦 Sharing the Image with Other Users

### Save and Share

```bash
# Save the image
./run-local.sh save /shared/agent-zero-model-overrides.tar.gz

# Other users load it
./run-local.sh load /shared/agent-zero-model-overrides.tar.gz
```

### Or Use a Local Registry

```bash
# Start local registry
docker run -d -p 5000:5000 --name registry registry:2

# Push to local registry
docker tag agent-zero:model-overrides localhost:5000/agent-zero:model-overrides
docker push localhost:5000/agent-zero:model-overrides

# Users can pull it
docker pull localhost:5000/agent-zero:model-overrides
```

---

## 🔧 Development Mode (No Rebuild)

For testing changes without rebuilding:

```bash
./run-local.sh dev
```

This mounts your local files directly into the container - changes are immediate.

---

## 📝 Docker Compose Examples

### Basic Usage

```yaml
version: '3'
services:
  agent-zero:
    image: agent-zero:model-overrides
    volumes:
      - ./data:/a0
    ports:
      - "50080:80"
```

### As Specific User

```yaml
version: '3'
services:
  agent-zero:
    image: agent-zero:model-overrides
    user: "1000:1000"  # UID:GID
    volumes:
      - /home/otheruser/a0-data:/a0
    ports:
      - "50080:80"
```

### With Environment Variables

```yaml
version: '3'
services:
  agent-zero:
    image: agent-zero:model-overrides
    volumes:
      - ./data:/a0
    ports:
      - "50080:80"
    environment:
      - API_KEY_OPENAI=${API_KEY_OPENAI}
      - API_KEY_ANTHROPIC=${API_KEY_ANTHROPIC}
```

---

## 🔍 Useful Commands

| Command | Description |
|---------|-------------|
| `./run-local.sh build` | Build the Docker image |
| `./run-local.sh run` | Run container directly |
| `./run-local.sh compose` | Run with docker-compose |
| `./run-local.sh stop` | Stop the container |
| `./run-local.sh logs` | View logs |
| `./run-local.sh save` | Save image to file |
| `./run-local.sh load` | Load image from file |
| `./run-local.sh dev` | Development mode |

---

## 🌐 Accessing the UI

| URL | Description |
|-----|-------------|
| http://localhost:50080 | Main web UI |
| http://localhost:50080/docs | API documentation |

---

## ⚙️ Customizing Model Overrides

1. Start the container
2. Click **Agents** button in sidebar
3. Select an agent profile (e.g., "Developer")
4. Edit model overrides
5. Save

The changes persist in the mounted volume (`./agent-zero-data`).

---

## 🐛 Troubleshooting

### Permission Denied

```bash
# Fix permissions
sudo chown -R $(id -u):$(id -g) ./agent-zero-data
```

### Port in Use

```bash
# Use different port
./run-local.sh compose -p 50081
```

### Container Won't Start

```bash
# Check logs
./run-local.sh logs
```

---

## 📚 More Info

- Full guide: `DOCKER_BUILD.md`
- Docker Compose file: `docker-compose.local.yml`
- Build script: `run-local.sh`
- Local Dockerfile: `Dockerfile.localdev`
