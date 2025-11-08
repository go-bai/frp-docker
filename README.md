# FRP Docker - Enterprise Grade Implementation

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com/)
[![NVIDIA](https://img.shields.io/badge/NVIDIA-GPU%20Ready-76B900?style=for-the-badge&logo=nvidia&logoColor=white)](https://www.nvidia.com/)
[![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)

A high-quality, enterprise-grade Docker container for [frp (Fast Reverse Proxy)](https://github.com/fatedier/frp) with intelligent mode detection, automatic binary management, supervisord process management, and NVIDIA GPU support. Built with enterprise-level code quality standards.

## Features

- **Dual Mode Operation**: Seamless server and client mode switching
- **Supervisord Process Management**: Both modes use supervisord as PID 1 for robust process management
- **Built-in SSH Server**: Optional SSH server for client mode (disabled by default)
- **Docker in Docker Support**: Built-in Docker CLI for managing containers (socket mount)
- **Golang Development Ready**: Pre-installed Go 1.25.4 for building and development
- **Node.js Development Ready**: Pre-installed NVM v0.40.1 for Node.js version management
- **Python Development Ready**: Pre-installed uv for ultra-fast Python package management
- **Git Version Control**: Pre-installed Git for source code management
- **NVIDIA GPU Support**: Ready for GPU workloads with nvidia-smi support
- **Ubuntu 22.04 Base**: Stable, well-supported base image with excellent compatibility
- **Intelligent CLI**: Interactive CLI tool for tunnel management (client mode)
- **Security First**: Automatic auth token generation and secure defaults
- **Sidecar Ready**: Perfect for container network namespace sharing
- **Auto-Download**: Automatic FRP binary download and updates
- **Multi-Arch**: Support for AMD64 and ARM64 architectures
- **Health Checks**: Built-in health monitoring for both modes
- **Enterprise Ready**: Comprehensive logging and configuration management

## Installation

```bash
# Pull the latest image from GitHub Container Registry
docker pull ghcr.io/go-bai/frp-docker:latest

# Or pull a specific version
docker pull ghcr.io/go-bai/frp-docker:v1.0.0
```

**Available Tags:**
- `latest` - Latest stable release
- `v1.0.0` - Specific version release

## Quick Start

### Server Mode

```bash
# Start FRP server
docker run -d \
  --name frp-server \
  --network host \
  -e FRP_MODE=server \
  ghcr.io/go-bai/frp-docker:latest

# Get authentication token
docker exec frp-server cat /app/configs/server_auth.txt

# Check server status
docker exec frp-server supervisorctl status
```

### Client Mode

```bash
# Start FRP client
docker run -d \
  --name frp-client \
  --network host \
  -e FRP_MODE=client \
  -e FRP_SERVER_ADDR=YOUR_SERVER_IP \
  -e FRP_SERVER_PORT=7000 \
  -e FRP_TOKEN=YOUR_AUTH_TOKEN \
  ghcr.io/go-bai/frp-docker:latest

# Access interactive CLI
docker exec -it frp-client frp-cli

# Check client status
docker exec frp-client supervisorctl status
```

### Client Mode with SSH Server

```bash
# Start FRP client
docker run -d \
  --name frp-client \
  --network host \
  -e FRP_MODE=client \
  -e FRP_SERVER_ADDR=YOUR_SERVER_IP \
  -e FRP_TOKEN=YOUR_AUTH_TOKEN \
  ghcr.io/go-bai/frp-docker:latest

# Enable SSH server (listens on port 22222)
docker exec frp-client supervisorctl start sshd

# Check SSH status
docker exec frp-client netstat -tlnp | grep 22222
```

### GPU-Enabled Container

```bash
# Start with GPU support (requires nvidia-container-toolkit on host)
docker run -d --gpus all \
  --name frp-client-gpu \
  -e FRP_MODE=client \
  -e FRP_SERVER_ADDR=YOUR_SERVER_IP \
  -e FRP_TOKEN=YOUR_AUTH_TOKEN \
  ghcr.io/go-bai/frp-docker:latest

# Test GPU access
docker exec frp-client-gpu nvidia-smi
```

### Sidecar Mode

```bash
# Start main application
docker run -d --name web-app nginx

# Start FRP client as sidecar
docker run -d \
  --name frp-sidecar \
  --network container:web-app \
  -e FRP_MODE=client \
  -e FRP_SERVER_ADDR=YOUR_SERVER_IP \
  -e FRP_TOKEN=YOUR_AUTH_TOKEN \
  ghcr.io/go-bai/frp-docker:latest
```

## Building from Source

```bash
git clone https://github.com/go-bai/frp-docker.git
cd frp-docker
make build
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FRP_MODE` | `client` | Operating mode: `client` or `server` |
| `FRP_VERSION` | `latest` | FRP version to download |
| `FRP_SERVER_ADDR` | `127.0.0.1` | Server address (client mode) |
| `FRP_SERVER_PORT` | `7000` | Server port |
| `FRP_WEB_PORT` | `7500` | Web dashboard port (server mode) |
| `FRP_TOKEN` | - | Authentication token |
| `FRP_LOG_LEVEL` | `info` | Log level: `debug`, `info`, `warn`, `error` |
| `FRP_ARCH` | auto-detect | Architecture: `amd64`, `arm64` |
| `NVIDIA_VISIBLE_DEVICES` | `all` | GPU devices to expose |
| `NVIDIA_DRIVER_CAPABILITIES` | `compute,utility` | GPU capabilities to enable |

### Networking Options

1. **Host Network**: `--network host` (recommended for server)
2. **Container Network**: `--network container:other-container` (sidecar mode)
3. **Bridge Network**: Default Docker bridge networking

## Process Management with Supervisord

Both server and client modes use supervisord as PID 1 for robust process management.

### Server Mode Process Tree
```
supervisord (PID 1)
└── frps (runs as frp user)
```

### Client Mode Process Tree
```
supervisord (PID 1)
├── frpc (runs as frp user, autostart=true)
└── sshd (runs as root, autostart=false, port 22222)
```

### Managing Services

```bash
# Check status
docker exec <container-name> supervisorctl status

# Start a service
docker exec <container-name> supervisorctl start <service-name>

# Stop a service
docker exec <container-name> supervisorctl stop <service-name>

# Restart a service
docker exec <container-name> supervisorctl restart <service-name>

# View all available commands
docker exec <container-name> supervisorctl help
```

### Service Names

- **Server mode**: `frps`
- **Client mode**: `frpc`, `sshd`

### Examples

```bash
# Server: restart FRP server
docker exec frp-server supervisorctl restart frps

# Client: enable SSH access
docker exec frp-client supervisorctl start sshd

# Client: restart FRP client
docker exec frp-client supervisorctl restart frpc

# Client: check all services
docker exec frp-client supervisorctl status
```

## SSH Server (Client Mode Only)

The client mode includes an optional SSH server that can be enabled for remote access to the container.

### Configuration
- **Port**: 22222 (listens on all interfaces)
- **Default State**: Disabled (`autostart=false`)
- **Configuration File**: `/etc/supervisor/conf.d/sshd.conf`

### Enable SSH Access

```bash
# 1. Start the SSH service
docker exec frp-client supervisorctl start sshd

# 2. Set root password (optional, if needed)
docker exec frp-client bash -c "echo 'root:your-password' | chpasswd"

# 3. Add your public key for key-based auth (recommended)
docker exec frp-client mkdir -p /root/.ssh
docker cp ~/.ssh/id_rsa.pub frp-client:/root/.ssh/authorized_keys
docker exec frp-client chmod 600 /root/.ssh/authorized_keys

# 4. Connect via SSH
ssh root@<container-ip> -p 22222
```

### Persistent SSH Host Keys

To avoid SSH host key warnings when recreating containers:

```bash
docker run -d \
  --name frp-client \
  -v ssh-keys:/etc/ssh \
  -e FRP_MODE=client \
  ghcr.io/go-bai/frp-docker:latest
```

## NVIDIA GPU Support

The container is pre-configured for GPU workloads.

### Prerequisites

**Host Requirements:**
1. NVIDIA GPU driver installed
2. nvidia-container-toolkit installed

```bash
# Install nvidia-container-toolkit (Ubuntu/Debian)
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

### Using GPU in Container

```bash
# Enable all GPUs
docker run -d --gpus all \
  --name frp-client \
  -e FRP_MODE=client \
  ghcr.io/go-bai/frp-docker:latest

# Enable specific GPU(s)
docker run -d --gpus '"device=0"' ...        # GPU 0 only
docker run -d --gpus '"device=0,1"' ...      # GPU 0 and 1

# Test GPU access
docker exec frp-client nvidia-smi
```

### GPU Environment Variables

The container includes these environment variables:
- `NVIDIA_VISIBLE_DEVICES=all` - Exposes all GPUs to the container
- `NVIDIA_DRIVER_CAPABILITIES=compute,utility` - Enables CUDA compute and nvidia-smi

## Docker in Docker Support

The container includes Docker CLI for managing containers within the FRP client/server.

### How It Works

The container uses **Docker socket mounting** to access the host's Docker daemon:
- Docker CLI is pre-installed in the image
- Mount the host's Docker socket: `/var/run/docker.sock`
- The `frp` user is added to the `docker` group for permissions

### Basic Usage

```bash
# Start container with Docker socket mounted
docker run -d \
  --name frp-client \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e FRP_MODE=client \
  -e FRP_SERVER_ADDR=your-server.com \
  -e FRP_TOKEN=your-token \
  ghcr.io/go-bai/frp-docker:latest

# Use Docker CLI inside the container
docker exec frp-client docker ps
docker exec frp-client docker images
docker exec frp-client docker run hello-world
```

### Use Cases

**1. Container Management via FRP Tunnel**

```bash
# Expose Docker socket via FRP tunnel
# In frpc.yaml, add:
proxies:
- name: "docker-api"
  type: "tcp"
  localIP: "127.0.0.1"
  localPort: 2375  # Docker API port
  remotePort: 12375

# Then manage containers remotely
docker -H tcp://your-server.com:12375 ps
```

**2. Build and Deploy Containers Remotely**

```bash
# Build image inside FRP container
docker exec frp-client docker build -t myapp:latest /path/to/dockerfile

# Run container
docker exec frp-client docker run -d myapp:latest
```

### Security Considerations

⚠️ **Important Security Notes:**

1. **Host Access**: Mounting Docker socket gives the container **full access** to the host's Docker daemon
2. **Root Equivalent**: Container can start privileged containers and mount host filesystems
3. **Trust**: Only mount the socket if you trust the container and its processes
4. **Alternative**: Consider using Docker's remote API with TLS authentication for production

**Recommended for**:
- ✅ Development and testing environments
- ✅ Trusted internal networks
- ✅ CI/CD pipelines

**Not recommended for**:
- ❌ Untrusted or public-facing containers
- ❌ Multi-tenant environments
- ❌ Production without additional security measures

### Verify Docker Access

```bash
# Check Docker CLI version
docker exec frp-client docker --version

# Test Docker access
docker exec frp-client docker info

# Check user permissions
docker exec frp-client id
docker exec frp-client groups
```

## Golang Development Environment

The container includes Go 1.25.4 pre-installed for building and development tasks.

### Environment

- **Go Version**: 1.25.4
- **GOROOT**: `/usr/local/go`
- **GOPATH**: `/go`
- **PATH**: Includes `/usr/local/go/bin` and `/go/bin`

### Basic Usage

```bash
# Check Go version
docker exec frp-client go version

# Build a Go project
docker exec frp-client go build -o /app/myapp main.go

# Run Go code
docker exec frp-client go run main.go

# Get dependencies
docker exec frp-client go get github.com/example/package

# Run tests
docker exec frp-client go test ./...
```

### Building Projects

**Example: Build a simple Go application**

```bash
# Create a simple Go program
docker exec frp-client bash -c 'cat > /tmp/hello.go << EOF
package main

import "fmt"

func main() {
    fmt.Println("Hello from FRP Docker!")
}
EOF'

# Build it
docker exec frp-client go build -o /tmp/hello /tmp/hello.go

# Run it
docker exec frp-client /tmp/hello
```

### With Volume Mount

```bash
# Mount your Go project into the container
docker run -d \
  --name frp-client \
  -v /path/to/your/go/project:/workspace \
  -e FRP_MODE=client \
  frp-docker:latest

# Build your project
docker exec frp-client sh -c "cd /workspace && go build"
```

### Available Go Tools

```bash
# Go commands
docker exec frp-client go version    # 1.25.4
docker exec frp-client go env         # Show environment
docker exec frp-client gofmt          # Format code
docker exec frp-client go vet         # Examine code
```

## Node.js Development Environment

The container includes NVM (Node Version Manager) pre-installed for managing Node.js versions.

### Environment

- **NVM Version**: v0.40.1
- **NVM Directory**: `/usr/local/nvm`
- **Auto-loaded**: NVM is automatically loaded in bash sessions

### Installing Node.js

```bash
# Source NVM (or start a new bash session)
docker exec frp-client bash -c "source /etc/bash.bashrc && nvm --version"

# Install latest LTS version
docker exec frp-client bash -c "source /etc/bash.bashrc && nvm install --lts"

# Install specific version
docker exec frp-client bash -c "source /etc/bash.bashrc && nvm install 20.11.0"

# Install latest version
docker exec frp-client bash -c "source /etc/bash.bashrc && nvm install node"

# List installed versions
docker exec frp-client bash -c "source /etc/bash.bashrc && nvm list"

# Use specific version
docker exec frp-client bash -c "source /etc/bash.bashrc && nvm use 20"
```

### Using Node.js

```bash
# Check Node.js version (after installation)
docker exec frp-client bash -c "source /etc/bash.bashrc && node --version"

# Check npm version
docker exec frp-client bash -c "source /etc/bash.bashrc && npm --version"

# Run a Node.js script
docker exec frp-client bash -c "source /etc/bash.bashrc && node script.js"

# Install packages with npm
docker exec frp-client bash -c "source /etc/bash.bashrc && npm install express"
```

### Persistent Node.js Installation

To persist Node.js versions across container restarts, mount the NVM directory:

```bash
docker run -d \
  --name frp-client \
  -v nvm-data:/usr/local/nvm \
  -e FRP_MODE=client \
  frp-docker:latest
```

### Example: Node.js Development

```bash
# Create a simple Express app
docker exec frp-client bash -c "source /etc/bash.bashrc && \
  nvm install --lts && \
  mkdir -p /workspace/myapp && \
  cd /workspace/myapp && \
  npm init -y && \
  npm install express"

# Create server file
docker exec frp-client bash -c 'cat > /workspace/myapp/server.js << EOF
const express = require("express");
const app = express();
app.get("/", (req, res) => res.send("Hello from FRP Docker!"));
app.listen(3000, () => console.log("Server running on port 3000"));
EOF'

# Run the server
docker exec frp-client bash -c "source /etc/bash.bashrc && \
  cd /workspace/myapp && \
  node server.js"
```

## Git Version Control

The container includes Git pre-installed for version control operations.

### Basic Usage

```bash
# Check Git version
docker exec frp-client git --version

# Configure Git (first time)
docker exec frp-client git config --global user.name "Your Name"
docker exec frp-client git config --global user.email "your.email@example.com"

# Clone a repository
docker exec frp-client git clone https://github.com/example/repo.git /workspace/repo

# Common Git operations
docker exec frp-client bash -c "cd /workspace/repo && git status"
docker exec frp-client bash -c "cd /workspace/repo && git add ."
docker exec frp-client bash -c "cd /workspace/repo && git commit -m 'Update'"
docker exec frp-client bash -c "cd /workspace/repo && git push"
```

### With Volume Mount

```bash
# Mount your project and use Git
docker run -d \
  --name frp-client \
  -v /path/to/your/project:/workspace \
  -v ~/.ssh:/root/.ssh:ro \
  -e FRP_MODE=client \
  frp-docker:latest

# Now you can use Git with SSH keys
docker exec frp-client bash -c "cd /workspace && git pull"
```

## Python Development with uv

The container includes **uv**, an extremely fast Python package installer and resolver from Astral.

### What is uv?

uv is a blazingly fast Python package installer and resolver, written in Rust. It's designed as a drop-in replacement for pip and pip-tools, offering:
- 10-100x faster than pip
- Single static binary with no dependencies
- pip-compatible interface
- Advanced dependency resolution

### Basic Usage

```bash
# Check uv version
docker exec frp-client uv --version

# Install a package
docker exec frp-client uv pip install requests

# Install from requirements.txt
docker exec frp-client uv pip install -r requirements.txt

# Create a virtual environment
docker exec frp-client uv venv /workspace/myproject/.venv

# Install packages in a virtual environment
docker exec frp-client bash -c "cd /workspace/myproject && uv pip install --python .venv/bin/python flask"
```

### Common Commands

```bash
# Install package (pip-compatible)
uv pip install <package>

# Install with specific version
uv pip install "requests==2.31.0"

# Install multiple packages
uv pip install requests flask pandas

# Install from requirements file
uv pip install -r requirements.txt

# Uninstall package
uv pip uninstall <package>

# List installed packages
uv pip list

# Freeze dependencies
uv pip freeze > requirements.txt

# Show package info
uv pip show <package>
```

### Creating Virtual Environments

```bash
# Create virtual environment
docker exec frp-client uv venv /workspace/myenv

# Activate and use
docker exec frp-client bash -c "source /workspace/myenv/bin/activate && uv pip install django"
```

### Example: Python Project Setup

```bash
# Create project structure
docker exec frp-client bash -c "mkdir -p /workspace/myapp && cd /workspace/myapp"

# Create virtual environment
docker exec frp-client uv venv /workspace/myapp/.venv

# Install dependencies
docker exec frp-client bash -c "cd /workspace/myapp && uv pip install --python .venv/bin/python fastapi uvicorn[standard]"

# Create a simple FastAPI app
docker exec frp-client bash -c 'cat > /workspace/myapp/main.py << EOF
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello from FRP Docker with uv!"}
EOF'

# Run the app
docker exec frp-client bash -c "cd /workspace/myapp && .venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8000"
```

### With Volume Mount

```bash
# Mount your Python project
docker run -d \
  --name frp-client \
  -v /path/to/your/python/project:/workspace \
  -e FRP_MODE=client \
  frp-docker:latest

# Use uv in your project
docker exec frp-client bash -c "cd /workspace && uv pip install -r requirements.txt"
```

### Performance Comparison

```bash
# Traditional pip (slow)
time pip install requests pandas numpy

# With uv (10-100x faster)
time uv pip install requests pandas numpy
```

### Advanced Features

```bash
# Compile requirements with version pinning
uv pip compile requirements.in -o requirements.txt

# Sync environment with requirements (install/uninstall as needed)
uv pip sync requirements.txt

# Install packages without modifying existing environment
uv pip install --no-deps <package>
```

## CLI Commands

The interactive CLI provides essential tunnel management for client mode:

```bash
# Access CLI in running client container
docker exec -it frp-client frp-cli

# Essential CLI commands:
frp-cli > help                    # Show help
frp-cli > status                  # Show connection and tunnel status
frp-cli > add web-tunnel 80 8080  # Add tunnel: local:80 -> remote:8080
frp-cli > add                     # Interactive tunnel creation
frp-cli > list                    # List all configured tunnels
frp-cli > remove web-tunnel       # Remove tunnel by name
frp-cli > exit                    # Exit CLI
```

### Interactive Tunnel Creation

```bash
frp-cli > add
╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗
║                                             ADD NEW TUNNEL                                                          ║
╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝

Tunnel Name: web-service
Local Port: 80
Remote Port: 8080
Protocol (tcp): tcp
✓ Tunnel 'web-service' added successfully!
```

## Security Features

- **Supervisord Process Management**: Robust process supervision and automatic restart
- **Automatic Token Generation**: Cryptographically secure authentication tokens
- **Service Isolation**: FRP runs as dedicated `frp` user (UID 1000)
- **SSH Optional**: SSH server disabled by default (client mode)
- **Input Validation**: Comprehensive input sanitization and validation
- **Secure Defaults**: Conservative security settings out-of-the-box
- **Health Monitoring**: Continuous health checks for early issue detection

## File Structure

### Project Structure (Source)

```
frp-docker/
├── build.sh                # Build automation script
├── Dockerfile              # Container definition (Ubuntu 22.04)
├── Makefile                # Build and test automation
├── README.md               # Project documentation
├── configs/                # Configuration templates
│   ├── supervisord.conf    # Supervisord main config
│   ├── frps.conf           # Server supervisor config
│   ├── frpc.conf           # Client supervisor config
│   └── sshd.conf           # SSH server config (client only)
├── scripts/                # Management scripts
│   ├── entrypoint.sh       # Main entry point
│   ├── download_frp.sh     # Binary management
│   ├── server_init.sh      # Server initialization
│   ├── client_init.sh      # Client initialization
│   ├── frp_cli.sh          # Interactive CLI
│   └── healthcheck.sh      # Health monitoring
└── tests/                  # Comprehensive test suite
    ├── README.md           # Test documentation
    ├── run_tests.sh        # Test runner
    ├── demo_*.sh           # Demo scripts
    ├── test_*.sh           # Unit and integration tests
    └── quick_test.sh       # Quick validation test
```

### Runtime Structure (Container)

```
/app/
├── frp/                    # FRP binaries (downloaded at runtime)
│   ├── frps                # Server binary
│   ├── frpc                # Client binary
│   ├── VERSION             # Installed version
│   └── INFO                # Installation metadata
├── configs/                # Configuration files
│   ├── supervisord.conf    # Supervisord config
│   ├── frps.conf           # Server supervisor config
│   ├── frpc.conf           # Client supervisor config
│   ├── sshd.conf           # SSH server config
│   ├── frps.yaml           # Server config (YAML format)
│   ├── frpc.yaml           # Client config (YAML format)
│   ├── server_auth.txt     # Server auth info
│   └── client_state.json   # Client tunnel state
├── logs/                   # Log files
│   ├── supervisord.log     # Supervisord logs
│   ├── frps_stdout.log     # Server stdout
│   ├── frps_stderr.log     # Server stderr
│   ├── frpc_stdout.log     # Client stdout
│   ├── frpc_stderr.log     # Client stderr
│   ├── sshd_stdout.log     # SSH stdout (if enabled)
│   └── sshd_stderr.log     # SSH stderr (if enabled)
└── scripts/                # Management scripts
    ├── entrypoint.sh       # Main entry point
    ├── download_frp.sh     # Binary management
    ├── server_init.sh      # Server initialization
    ├── client_init.sh      # Client initialization
    ├── frp_cli.sh          # Interactive CLI
    └── healthcheck.sh      # Health monitoring

/etc/supervisor/conf.d/     # Supervisor service configs
├── frps.conf               # Server service (server mode)
├── frpc.conf               # Client service (client mode)
└── sshd.conf               # SSH service (client mode, disabled by default)
```

## Advanced Usage

### Custom Binary Version

```bash
docker run -e FRP_VERSION=v0.52.0 ghcr.io/go-bai/frp-docker:latest
```

### Development Mode with Debug Logging

```bash
docker run -e FRP_LOG_LEVEL=debug ghcr.io/go-bai/frp-docker:latest
```

### Multi-Container Network Sharing

```bash
# Create shared network
docker network create frp-net

# Start containers
docker run --network frp-net --name app my-app
docker run --network container:app --name frp-client ghcr.io/go-bai/frp-docker:latest
```

### Persistent Configuration and SSH Keys

```bash
docker run -d \
  -v $(pwd)/frp-config:/app/configs \
  -v ssh-keys:/etc/ssh \
  -e FRP_MODE=client \
  ghcr.io/go-bai/frp-docker:latest
```

## Monitoring & Logging

### Health Checks

Built-in health checks monitor:
- Configuration file integrity
- Binary availability and executability
- Log file activity
- Process responsiveness

### Log Management

- Automatic log rotation (configured in supervisord)
- Structured logging with timestamps
- Separate stdout/stderr streams for each service
- Debug mode for troubleshooting
- Centralized logs in `/app/logs/`

### Viewing Logs

```bash
# View supervisord logs
docker exec frp-server cat /app/logs/supervisord.log

# View FRP server logs
docker exec frp-server cat /app/logs/frps_stdout.log

# View FRP client logs
docker exec frp-client cat /app/logs/frpc_stdout.log

# View SSH logs (if enabled)
docker exec frp-client cat /app/logs/sshd_stdout.log

# Follow logs in real-time
docker exec frp-server tail -f /app/logs/frps_stdout.log
```

### Web Dashboard (Server Mode)

Access the web dashboard at `http://server-ip:7500`:
- Username: `admin`
- Password: `<auth-token>` (from `/app/configs/server_auth.txt`)

## Performance & Scalability

- **Ubuntu 22.04 Base**: ~250MB image size
- **Supervisord Management**: Efficient process supervision
- **Fast Startup**: Intelligent caching and binary reuse
- **Resource Efficient**: Minimal CPU and memory footprint
- **Connection Pooling**: Optimized connection management
- **Compression**: Built-in data compression support
- **GPU Ready**: Optimized for GPU workloads

## Troubleshooting

### Common Issues

1. **Connection Refused**
   ```bash
   # Check server is listening
   docker exec frp-server netstat -tlnp | grep 7000

   # Check supervisord status
   docker exec frp-server supervisorctl status

   # Verify firewall settings
   docker exec frp-server /app/scripts/healthcheck.sh
   ```

2. **Authentication Failed**
   ```bash
   # Get current auth token
   docker exec frp-server cat /app/configs/server_auth.txt

   # Update client token and access CLI
   docker exec -it frp-client frp-cli
   ```

3. **Binary Download Issues**
   ```bash
   # Force binary re-download
   docker exec frp-client rm -rf /app/frp/*
   docker restart frp-client
   ```

4. **Service Not Starting**
   ```bash
   # Check supervisord logs
   docker exec <container> cat /app/logs/supervisord.log

   # Check service-specific logs
   docker exec <container> cat /app/logs/frps_stderr.log
   docker exec <container> cat /app/logs/frpc_stderr.log

   # Restart service
   docker exec <container> supervisorctl restart <service-name>
   ```

5. **SSH Connection Issues**
   ```bash
   # Check if SSH is running
   docker exec frp-client supervisorctl status sshd

   # Check SSH logs
   docker exec frp-client cat /app/logs/sshd_stderr.log

   # Verify SSH is listening
   docker exec frp-client netstat -tlnp | grep 22222
   ```

6. **GPU Not Detected**
   ```bash
   # Check if nvidia-smi is available
   docker exec <container> nvidia-smi

   # Verify GPU environment variables
   docker exec <container> env | grep NVIDIA

   # Check host GPU status
   nvidia-smi

   # Verify nvidia-container-toolkit is installed
   docker run --rm --gpus all ubuntu:22.04 nvidia-smi
   ```

### Debug Mode

```bash
# Enable debug logging
docker run -e FRP_LOG_LEVEL=debug ghcr.io/go-bai/frp-docker:latest

# View container logs
docker logs -f container-name

# View supervisord logs
docker exec container-name cat /app/logs/supervisord.log

# Interactive shell for debugging
docker exec -it container-name bash
```

## Testing

This project includes a comprehensive test suite to ensure reliability and functionality.

### Running Tests

```bash
# Run all tests
./tests/run_tests.sh

# Run only unit tests
./tests/run_tests.sh unit

# Run only demonstrations
./tests/run_tests.sh demo

# Run individual test
./tests/test_tunnel.sh
```

### Test Coverage

- **Unit Tests**: Core functionality testing
- **Integration Tests**: CLI and configuration testing
- **End-to-End Tests**: Complete workflow demonstrations
- **Performance Tests**: Resource usage and timing

See [`tests/README.md`](tests/README.md) for detailed test documentation.

## Contributing

This project follows enterprise-grade development practices:

- Comprehensive error handling and logging
- Input validation and security checks
- Extensive documentation and examples
- Health monitoring and observability
- Clean, maintainable code architecture

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- [fatedier/frp](https://github.com/fatedier/frp) - The excellent FRP project
- Ubuntu team for the stable base image
- NVIDIA for GPU container runtime
- Supervisord for process management
- Docker community for containerization standards

---

**Built with enterprise-grade quality standards**
