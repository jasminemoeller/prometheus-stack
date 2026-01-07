# Prometheus Monitoring Stack

A production-ready minimalist Docker Compose setup for Prometheus monitoring with:
- Prometheus server
- Grafana dashboard
- cAdvisor for container metrics
- blackbox_exporter for more data acquisition (currently empty)
- Dynamic target discovery via file-based service discovery

The setup is specifically targeted at small homelabs and does not rely on kubernetes, swarm etc. Just a single monitoring server and a bunch of hosts to monitor

Alerting is not yet implemented. For a homelab setup it will likely be good enough to implement this in grafana, only.

This setup does not expose prometheus itself via Traefik. If you need to access prometheus directly, either publish the port in the compose file or fire up a temporary sidecar container.

This setup uses:
- An **external** reverse proxy which is connected to the webservices network. Feel free to drop in your own traefik service.
- Runs the node_exporter directly on the host (i.e. **not** as part of the stack), as recommended by the prometheus team
- cAdvisor runs on the server in **host** network mode to keep the node name and metrics stable over redeployments (I guess this can be done differently)

## Quick Start

### Set up the server

1. Clone this repository:
```bash
   git clone https://github.com/YOUR_USERNAME/prometheus-stack.git
   cd prometheus-stack
```

2. Customize your targets:
   - Edit `prometheus/targets/nodes/hosts.yml` with your server hostnames/IPs
   - Edit `prometheus/targets/cadvisor/hosts.yml` with your docker server hostnames/IPs

3. Customize/Populate the blackbox exporter:
   - Edit `blackbox/blackbox.yml`

3. Customize the stack:
   - Either provide the required environment variables, set up suitable secrets or just edit the compose file directly.

4. Start the stack:
```bash
   docker compose up -d
```

5. Access Grafana at `http(s)://${MONITORING_DOMAIN_PUBLIC}

### Set up the clients

The clients directory contains a systemd unit file for node_exporter and a minimal compose stack for cAdvisor. Use one or both on the server and/or docker hosts you want to monitor. You obviously need to download node_exporter (https://prometheus.io/download/) and place it in /usr/local/bin (or wherever you like) and set up the systemd unit (this is outside the scope of this README)

## Configuration

### Target Files

Prometheus uses file-based service discovery for dynamic target management. Edit these files to add/remove monitoring targets:

- `prometheus/targets/nodes/*.yml` - Node Exporter targets (port 9100)
- `prometheus/targets/cadvisor/*.yml` - cAdvisor targets (port 8080)

Changes to these files are picked up automatically without restarting Prometheus.

### Example Target Format
```yaml
- targets: ['hostname:9100']
  labels:
    instance: 'hostname.example.com'
```

## Architecture

- **Prometheus**: Metrics collection and storage
- **Grafana**: Dashboards and alerting
- **Node Exporter**: System/hardware metrics (CPU, memory, disk, network)
- **cAdvisor**: Container metrics (Docker resource usage)

## License

MIT