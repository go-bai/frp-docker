# FRP Docker - Enterprise Grade Implementation

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://www.linux.org/)
[![Shell Script](https://img.shields.io/badge/shell_script-%23121011.svg?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)

A high-quality, enterprise-grade Docker container for [frp (Fast Reverse Proxy)](https://github.com/fatedier/frp) with intelligent mode detection, automatic binary management, and advanced CLI tooling. Built with Linus-level code quality standards.

## 🚀 Features

- **🔄 Dual Mode Operation**: Seamless server and client mode switching
- **📱 Intelligent CLI**: Interactive shell for tunnel management
- **🔐 Security First**: Automatic auth token generation and secure defaults
- **🏗️ Sidecar Ready**: Perfect for container network namespace sharing
- **📦 Auto-Download**: Automatic FRP binary download and updates
- **🎯 Multi-Arch**: Support for AMD64 and ARM64 architectures
- **🔍 Health Checks**: Built-in health monitoring for both modes
- **📊 Enterprise Ready**: Comprehensive logging and configuration management

## 📋 Quick Start

### Server Mode

```bash
# Start FRP server
docker run -d \
  --name frp-server \
  --network host \
  -e FRP_MODE=server \
  frp-docker

# Get authentication token
docker exec frp-server cat /app/configs/server_auth.txt
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
  frp-docker

# Access interactive CLI
docker exec -it frp-client shell
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
  frp-docker
```

## 🛠️ Building

```bash
git clone <repository>
cd frp-docker
docker build -t frp-docker .
```

## ⚙️ Configuration

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

### Networking Options

1. **Host Network**: `--network host` (recommended for server)
2. **Container Network**: `--network container:other-container` (sidecar mode)
3. **Bridge Network**: Default Docker bridge networking

## 🎮 CLI Commands

The simplified interactive CLI provides essential tunnel management:

```bash
# Access CLI (multiple ways)
docker exec -it frp-client frp-cli
# OR
docker exec -it frp-client shell

# Essential commands:
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

## 📚 Docker Compose Examples

### Complete Server Setup

```yaml
version: '3.8'
services:
  frp-server:
    build: .
    container_name: frp-server
    restart: unless-stopped
    network_mode: host
    environment:
      - FRP_MODE=server
      - FRP_SERVER_PORT=7000
      - FRP_WEB_PORT=7500
    volumes:
      - frp_server_data:/app/configs
      - frp_server_logs:/app/logs
    healthcheck:
      test: ["CMD", "/app/scripts/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
volumes:
  frp_server_data:
  frp_server_logs:
```

### Client with Sidecar Pattern

```yaml
version: '3.8'
services:
  web-app:
    image: nginx:alpine
    container_name: web-app
    ports:
      - "8080:80"

  frp-client:
    build: .
    container_name: frp-client
    network_mode: "container:web-app"
    environment:
      - FRP_MODE=client
      - FRP_SERVER_ADDR=your-server.com
      - FRP_TOKEN=your-auth-token
    depends_on:
      - web-app
```

## 🔒 Security Features

- **Automatic Token Generation**: Cryptographically secure authentication tokens
- **Non-Root Execution**: Runs as dedicated `frp` user (UID 1000)
- **Input Validation**: Comprehensive input sanitization and validation
- **Secure Defaults**: Conservative security settings out-of-the-box
- **Health Monitoring**: Continuous health checks for early issue detection

## 📁 File Structure

```
/app/
├── frp/                 # FRP binaries
│   ├── frps            # Server binary
│   ├── frpc            # Client binary
│   ├── VERSION         # Installed version
│   └── INFO            # Installation metadata
├── configs/            # Configuration files
│   ├── frps.ini        # Server config
│   ├── frpc.ini        # Client config
│   ├── server_auth.txt # Server auth info
│   └── client_state.json # Client state
├── logs/               # Log files
│   ├── frps.log        # Server logs
│   └── frpc.log        # Client logs
└── scripts/            # Management scripts
    ├── entrypoint.sh   # Main entry point
    ├── download_frp.sh # Binary management
    ├── server_init.sh  # Server initialization
    ├── client_init.sh  # Client initialization
    ├── frp_cli.sh      # Interactive CLI
    └── healthcheck.sh  # Health monitoring
```

## 🔧 Advanced Usage

### Custom Binary Version

```bash
docker run -e FRP_VERSION=v0.52.0 frp-docker
```

### Development Mode with Debug Logging

```bash
docker run -e FRP_LOG_LEVEL=debug frp-docker
```

### Multi-Container Network Sharing

```bash
# Create shared network
docker network create frp-net

# Start containers
docker run --network frp-net --name app my-app
docker run --network container:app --name frp-client frp-docker
```

### Persistent Configuration

```bash
docker run -v $(pwd)/frp-config:/app/configs frp-docker
```

## 📊 Monitoring & Logging

### Health Checks

Built-in health checks monitor:
- Configuration file integrity
- Binary availability and executability
- Log file activity
- Process responsiveness

### Log Management

- Automatic log rotation (7 days retention)
- Structured logging with timestamps
- Separate server/client log streams
- Debug mode for troubleshooting

### Web Dashboard (Server Mode)

Access the web dashboard at `http://server-ip:7500`:
- Username: `admin`
- Password: `<auth-token>`

## 🚀 Performance & Scalability

- **Lightweight**: Alpine Linux base (~50MB total)
- **Fast Startup**: Intelligent caching and binary reuse
- **Resource Efficient**: Minimal CPU and memory footprint
- **Connection Pooling**: Optimized connection management
- **Compression**: Built-in data compression support

## 🛟 Troubleshooting

### Common Issues

1. **Connection Refused**
   ```bash
   # Check server is listening
   docker exec frp-server netstat -tlnp | grep 7000

   # Verify firewall settings
   docker exec frp-server /app/scripts/healthcheck.sh
   ```

2. **Authentication Failed**
   ```bash
   # Get current auth token
   docker exec frp-server cat /app/configs/server_auth.txt

   # Update client token
   docker exec -it frp-client shell
   frp-cli > login
   ```

3. **Binary Download Issues**
   ```bash
   # Force binary re-download
   docker exec frp-client rm -rf /app/frp/*
   docker restart frp-client
   ```

### Debug Mode

```bash
docker run -e FRP_LOG_LEVEL=debug frp-docker
docker logs -f container-name
```

## 🧪 Testing

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

## 🤝 Contributing

This project follows enterprise-grade development practices:

- Comprehensive error handling and logging
- Input validation and security checks
- Extensive documentation and examples
- Health monitoring and observability
- Clean, maintainable code architecture

## 📄 License

MIT License - see LICENSE file for details.

## 🙏 Acknowledgments

- [fatedier/frp](https://github.com/fatedier/frp) - The excellent FRP project
- Alpine Linux team for the lightweight base image
- Docker community for containerization standards

---

**Built with ❤️ and enterprise-grade quality standards**