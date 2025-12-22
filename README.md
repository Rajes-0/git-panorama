# GitStats

**Understand your engineering organization through data.**

GitStats provides cross-referenced analytics across teams, repositories, and individual contributors. See who's contributing where, which repositories are most active, and how your engineering efforts are distributed across projects.

---

## What You Get

### Business Insights

**Team Performance**
- Contribution trends over time
- Active vs. inactive repositories
- Team velocity and output metrics
- Cross-team collaboration patterns

**Resource Allocation**
- Effort distribution across projects
- Contributor activity by repository
- Identify bottlenecks and dependencies
- Understand where engineering time is spent

**Individual Contributions**
- Personal contribution history
- Repository ownership and expertise
- Activity patterns and engagement
- Recognition and performance data

### Cross-Referenced Views

The power of GitStats is in the relationships:

```
Team View          Repository View      Personal View
    ↓                     ↓                   ↓
    └─────────────────────┴───────────────────┘
                          │
                    Unified Data
                          │
    "Who works on what?" "Where is effort spent?" "What's the impact?"
```

**Example Questions Answered:**
- Which repositories have the most contributors?
- Who are the domain experts for each project?
- How is engineering effort distributed across teams?
- Which projects are actively maintained vs. stagnant?
- What's the contribution pattern of each team member?

---

## Quick Start

```bash
./install.sh  # One-time setup: install dependencies and start services
./run.sh      # Regular usage: clone/update repos, analyze, and update dashboards
```

**View Dashboards:** http://localhost:3000 (admin/admin)

That's it. The system handles the rest - including cloning new repositories from config.yaml.

---

## Installation

### Prerequisites

- Docker Desktop
- Python 3.8+
- Git access to your repositories

### Setup (5 minutes)

```bash
# 1. Clone and install (one-time)
git clone <this-repo>
cd gitstats
./install.sh

# 2. Configure repositories and team members
cp config.yaml.sample config.yaml
# Edit config.yaml to:
#   - Add repository URLs to repositories.repository_urls
#   - Map email addresses to people in email_mapping

# 3. Generate insights (this will clone repos automatically)
./run.sh
```

**Done.** Open http://localhost:3000 to see your dashboards.

---

## Dashboards

### 1. Team Overview

**Purpose:** Understand overall engineering activity and trends.

- Total commits and lines changed over time
- Top contributors across all repositories
- Active vs. inactive projects
- Team velocity trends

**Use Cases:**
- Monthly/quarterly engineering reviews
- Team capacity planning
- Identifying high-impact contributors
- Spotting activity patterns

### 2. Repository Overview

**Purpose:** Compare projects and understand resource allocation.

- Commits by repository
- Contributors per project
- Activity heatmaps
- Repository health indicators

**Use Cases:**
- Project prioritization decisions
- Resource allocation reviews
- Identifying unmaintained projects
- Understanding project complexity

### 3. Personal Overview

**Purpose:** Individual contributor insights and recognition.

- Personal commit history
- Lines changed by contributor
- Repository contributions
- Activity patterns

**Use Cases:**
- Performance reviews
- Recognizing contributions
- Understanding expertise areas
- Career development discussions

### 4. Contribution Calendar

**Purpose:** GitHub-style activity visualization.

- Visual activity heatmap
- Contribution patterns
- Dynamic filtering by repository/author
- Spot trends and anomalies

---

## Configuration

### Email Mapping (Recommended)

Contributors often use multiple email addresses. Map them to ensure accurate attribution:

```yaml
email_mapping:
  "Jane Doe":
    - "jane@company.com"
    - "jane.doe@company.com"
    - "jane@personal.com"
```

**Why this matters:** Without mapping, Jane appears as three different people in your analytics.

### Repository Selection

```yaml
repositories:
  base_directory: "./repositories"
  
  # Analyze specific repos (empty = all)
  repositories_to_analyze: []
  
  # URLs for automated cloning
  repository_urls:
    - "git@github.com:yourorg/repo1.git"
    - "git@github.com:yourorg/repo2.git"
```

### Date Range (Optional)

Focus on recent activity:

```yaml
analysis:
  start_date: "2024-01-01"  # or leave empty for all time
  end_date: ""               # empty = until now
```

### File Exclusions

Exclude generated files to focus on meaningful code:

```yaml
exclusions:
  patterns:
    - pattern: ".*\\.lock$"
      description: "Lock files"
    - pattern: ".*/node_modules/.*"
      description: "Dependencies"
```

**Why this matters:** Including generated files inflates metrics and obscures real contributions.

---

## Daily Operations

### Update Statistics

```bash
./run.sh
```

**Safe to run anytime.** The script will:
1. Clone any new repositories from config.yaml
2. Fetch latest changes from all existing repositories
3. Analyze commits and generate statistics
4. Upload data to Elasticsearch

The system is idempotent—running multiple times won't create duplicates.

**Automate it:**
```bash
# Add to crontab for daily updates at 2 AM
0 2 * * * cd /path/to/gitstats && ./run.sh >> logs/run.log 2>&1
```

### View Current Data

```bash
# Check document counts
curl http://localhost:9200/_cat/indices/git-*?v

# View in browser
open http://localhost:1358  # Elasticsearch browser
open http://localhost:3000  # Grafana dashboards
```

### Find Unmapped Emails

```bash
python3 scripts/find_unmapped_emails.py config.yaml
```

This shows email addresses not yet mapped to people in your config.

---

## Testing

### Verify Services

```bash
# All services running?
docker compose ps

# Elasticsearch healthy?
curl http://localhost:9200/_cluster/health

# Grafana responding?
curl http://localhost:3000/api/health
```

### Verify Data

```bash
# Check data count
curl http://localhost:9200/git-commits/_count

# Browse data visually
open http://localhost:1358
```

### Test Dashboards

1. Open http://localhost:3000 (admin/admin)
2. Navigate to Dashboards
3. Verify panels load data
4. Test filters (repository, author, date range)

---

## Architecture

### Services

| Service | Port | Purpose |
|---------|------|---------|
| Grafana | 3000 | Dashboards and visualization |
| Elasticsearch | 9200 | Data storage and search |
| Dejavu | 1358 | Data browser (optional) |

### Data Flow

```
Git Repositories
    ↓
Python Analyzers (parallel processing)
    ↓
Elasticsearch (idempotent storage)
    ↓
Grafana Dashboards (real-time queries)
```

### How Idempotency Works

Each commit has a unique ID: `{repository}_{commit_hash}`

Running `./run.sh` multiple times updates existing data instead of creating duplicates.

### Smart Caching

The system caches analysis results and only re-analyzes repositories when they change (detected via git refs). This makes subsequent updates fast.

**Clear cache to force re-analysis:**
```bash
./scripts/clear-cache.sh
```

---

## Troubleshooting

### No Data in Dashboards

```bash
# 1. Verify Elasticsearch has data
curl http://localhost:9200/git-commits/_count

# 2. Clear Grafana cache
./scripts/clear-grafana-cache.sh

# 3. Refresh browser (Cmd+Shift+R)
```

### Services Not Starting

```bash
# Check Docker is running
docker ps

# View logs
docker compose logs elasticsearch
docker compose logs grafana

# Restart
docker compose restart
```

### Analysis Fails

```bash
# Check dependencies
python3 -c "import yaml; import dateutil"

# Reinstall if needed
uv pip install -r requirements.txt --system

# Validate config
python3 -c "import yaml; yaml.safe_load(open('config.yaml'))"
```

### Port Conflicts

Edit `docker-compose.yml` to change ports if 3000 or 9200 are already in use.

---

## Production Deployment

### Security Checklist

- [ ] Change default Grafana password
- [ ] Set Elasticsearch password in `.env`
- [ ] Use HTTPS for external access
- [ ] Restrict network access (firewall)
- [ ] Regular backups of `./storage/elasticsearch/`

### Environment Variables

Create `.env` file:

```bash
ELASTIC_PASSWORD=your-secure-password
GF_ADMIN_PASSWORD=your-secure-password
```

### Backup & Restore

```bash
# Backup
tar -czf gitstats-backup-$(date +%Y%m%d).tar.gz ./storage/elasticsearch/

# Restore
docker compose down
tar -xzf gitstats-backup-YYYYMMDD.tar.gz
docker compose up -d
```

### External Elasticsearch

```bash
export ES_HOST=elasticsearch.example.com
export ES_PORT=9200
./run.sh
```

---

## Advanced Usage

### Multiple Teams

Use separate config files:

```bash
CONFIG_FILE=config-team-a.yaml ./run.sh
CONFIG_FILE=config-team-b.yaml ./run.sh
```

### Custom Dashboards

1. Create dashboard in Grafana UI
2. Export as JSON
3. Save to `config/grafana/provisioning/dashboards/`
4. Restart: `docker restart gitstats-grafana`

### Performance Tuning

For large repositories:

```yaml
# Limit date range
analysis:
  start_date: "2024-01-01"

# Exclude merge commits
analysis:
  exclude_merge_commits: true

# Adjust parallelization
parallelization:
  max_workers: 8  # increase for more CPU cores
```

---

## Configuration Reference

### Complete config.yaml Structure

```yaml
# Email mapping (recommended)
email_mapping:
  "Person Name":
    - "email1@company.com"
    - "email2@company.com"

# Repository configuration
repositories:
  base_directory: "./repositories"
  repositories_to_analyze: []  # empty = all
  repository_urls:
    - "git@github.com:org/repo.git"
  include_all_files:  # repos with no exclusions
    - "build-tools-repo"

# Analysis settings
analysis:
  start_date: ""  # YYYY-MM-DD or empty
  end_date: ""
  all_branches: true
  exclude_merge_commits: true
  output_directory: "./git-stats"

# File exclusions
exclusions:
  patterns:
    - pattern: ".*\\.lock$"
      description: "Lock files"
  always_include:
    - pattern: ".*/package\\.json$"
      description: "Package configs"
  repository_specific:
    repo-name:
      include_patterns:
        - pattern: ".*\\.xml$"

# Elasticsearch
elasticsearch:
  host: "localhost"
  port: 9200
  commit_index: "git-commits"
  bulk_batch_size: 3000

# Parallelization
parallelization:
  max_workers: null  # null = auto-detect CPU count
```

---

## Maintenance

### Regular Tasks

```bash
# Daily: Update statistics (automate via cron)
./run.sh

# Weekly: Check for unmapped emails
python3 scripts/find_unmapped_emails.py config.yaml

# Monthly: Backup data
tar -czf backup-$(date +%Y%m%d).tar.gz ./storage/elasticsearch/
```

### Monitoring

```bash
# Elasticsearch health
curl http://localhost:9200/_cluster/health

# Index sizes
curl http://localhost:9200/_cat/indices/git-*?v

# Docker resources
docker stats
```

---

## Technology Stack

- **Docker Compose** - Container orchestration
- **Elasticsearch 8.17** - Data storage and search
- **Grafana** - Visualization and dashboards
- **Python 3.8+** - Analysis scripts
- **uv** - Fast Python package manager (10-100x faster than pip)

---

## Support

### Common Issues

**Port conflicts:** Change ports in `docker-compose.yml`  
**Memory errors:** Increase ES heap size in `docker-compose.yml`  
**Slow analysis:** Adjust parallelization in `config.yaml`  
**Missing data:** Check repository access and config validation

### Logs

```bash
# Application logs
tail -f logs/run.log

# Docker logs
docker compose logs -f
docker compose logs elasticsearch
docker compose logs grafana
```

### Getting Help

1. Check logs for error messages
2. Verify configuration: `python3 -c "import yaml; yaml.safe_load(open('config.yaml'))"`
3. Test services individually (see Testing section)
4. Review configuration reference above

---

## Philosophy

**Simple by default.** Two commands: `./install.sh` once, then `./run.sh` daily.

**Safe to experiment.** Idempotent operations mean you can run `./run.sh` as often as you want without breaking anything.

**Data-driven insights.** Make engineering decisions based on actual activity, not assumptions.

**Respect privacy.** All data stays on your infrastructure. No external services required.

---

## What's Next?

1. **Start small:** Analyze a few repositories first
2. **Refine configuration:** Add email mappings as you discover them
3. **Automate updates:** Set up daily cron jobs with `./run.sh`
4. **Share insights:** Use dashboards in team meetings
5. **Iterate:** Customize dashboards for your specific needs

The goal is simple: understand your engineering organization better. GitStats gives you the data. You bring the insights.

---

*Built with care for engineering teams who value transparency and data-driven decisions.*
