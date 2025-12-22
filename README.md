# Git Panorama

> Who's shipping? What's shipping? Where's the effort going?

Your git history knows. Let's ask it.

---

## The Problem

You have questions:
- Which repos are actually maintained vs. quietly dying?
- Who are the domain experts on each project?
- Where is engineering time *actually* going?
- Is this person overloaded or coasting?

Your git history has answers. But it's scattered across dozens of repositories, thousands of commits, and multiple email addresses per person.

**Git Panorama** aggregates it all, deduplicates contributors, and surfaces insights through beautiful Grafana dashboards.

---

## Quick Start

```bash
./install.sh  # Once: dependencies + services
./run.sh      # Always: clone/update repos, analyze, upload
```

Open http://localhost:3000 (admin/admin).

Done.

---

## What You Get

### Four Dashboards

**Team Overview** - Org-level metrics. Commits over time, top contributors, velocity trends.

**Repository Overview** - Project comparison. Which repos are hot, which are not, who's working where.

**Personal Overview** - Individual impact. Commit history, lines changed, expertise areas.

**Contribution Calendar** - GitHub-style heatmap. Because everyone loves green squares.

### Cross-Referenced Everything

Click a person → see their repos.  
Click a repo → see its contributors.  
Click a date range → filter everything.

The power is in the relationships.

---

## Installation

**Prerequisites:**
- Docker Desktop
- Python 3.12+
- Git access to your repos

**Setup:**

```bash
git clone <this-repo>
cd git-panorama
./install.sh

# Configure
cp config.yaml.sample config.yaml
# Edit: add repo URLs, map emails to people

# Run
./run.sh
```

That's it. Open http://localhost:3000.

---

## Configuration

### Email Mapping (Important!)

People use multiple emails. Map them or they appear as separate contributors:

```yaml
email_mapping:
  "Jane Doe":
    - "jane@company.com"
    - "jane.doe@company.com"
    - "jane@personal.com"
```

Find unmapped emails:
```bash
python3 scripts/find_unmapped_emails.py config.yaml
```

### Repository URLs

List repos to auto-clone:

```yaml
repositories:
  repository_urls:
    - "git@github.com:yourorg/repo1.git"
    - "git@github.com:yourorg/repo2.git"
```

Leave `repositories_to_analyze` empty to analyze all cloned repos.

### File Exclusions

Exclude noise:

```yaml
exclusions:
  patterns:
    - pattern: ".*\\.lock$"
      description: "Lock files"
    - pattern: ".*/node_modules/.*"
      description: "Dependencies"
    - pattern: ".*-generated\\..*"
      description: "Generated code"
```

Lock files and generated code aren't real contributions. Exclude them.

### Date Range (Optional)

Focus on recent activity:

```yaml
analysis:
  start_date: "2024-01-01"  # or empty for all time
  end_date: ""               # empty = now
```

---

## Daily Usage

### Update Everything

```bash
./run.sh
```

Idempotent. Run it as often as you want. It will:
1. Clone new repos from config
2. Fetch latest changes
3. Analyze commits
4. Upload to Elasticsearch

No duplicates. No corruption. Just fresh data.

### Automate It

```bash
# Cron: daily at 2 AM
0 2 * * * cd /path/to/git-panorama && ./run.sh >> logs/run.log 2>&1
```

### Check Data

```bash
# Document count
curl http://localhost:9200/git-commits/_count

# Browse data
open http://localhost:1358  # Elasticsearch browser
```

---

## Architecture

### Services

| Service | Port | Purpose |
|---------|------|---------|
| Grafana | 3000 | Dashboards |
| Elasticsearch | 9200 | Data storage |
| Dejavu | 1358 | Data browser (optional) |

### Data Flow

```
Git Repos
    ↓
Python (parallel analysis)
    ↓
Elasticsearch (idempotent upsert)
    ↓
Grafana (real-time queries)
```

### Idempotency

Each commit gets a unique ID: `{repository}_{commit_hash}`

Running `./run.sh` multiple times updates existing data instead of duplicating it.

### Smart Caching

Analysis results are cached. Re-analysis only happens when repos change (detected via git refs).

Clear cache to force full re-analysis:
```bash
./scripts/clear-cache.sh
```

---

## Troubleshooting

### No Data in Dashboards

```bash
# 1. Verify data exists
curl http://localhost:9200/git-commits/_count

# 2. Clear Grafana cache
./scripts/clear-grafana-cache.sh

# 3. Hard refresh browser
# Cmd+Shift+R (Mac) / Ctrl+Shift+R (Windows/Linux)
```

### Services Won't Start

```bash
# Check Docker
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

# Reinstall
uv pip install -r requirements.txt --system

# Validate config
python3 -c "import yaml; yaml.safe_load(open('config.yaml'))"
```

### Port Conflicts

Edit `docker-compose.yml` to change ports if 3000 or 9200 are taken.

---

## Advanced

### Multiple Teams

Use separate configs:

```bash
CONFIG_FILE=config-team-a.yaml ./run.sh
CONFIG_FILE=config-team-b.yaml ./run.sh
```

### Custom Dashboards

1. Create in Grafana UI
2. Export as JSON
3. Save to `config/grafana/provisioning/dashboards/`
4. Restart: `docker restart gitstats-grafana`

### Performance Tuning

For large repos:

```yaml
# Limit date range
analysis:
  start_date: "2024-01-01"

# Exclude merge commits
analysis:
  exclude_merge_commits: true

# More parallelism
parallelization:
  max_workers: 8  # increase for more CPU cores
```

### External Elasticsearch

```bash
export ES_HOST=elasticsearch.example.com
export ES_PORT=9200
./run.sh
```

---

## Production

### Security Checklist

- [ ] Change default Grafana password
- [ ] Set Elasticsearch password in `.env`
- [ ] Use HTTPS for external access
- [ ] Restrict network access (firewall)
- [ ] Regular backups of `./storage/elasticsearch/`

### Environment Variables

Create `.env`:

```bash
ELASTIC_PASSWORD=your-secure-password
GF_ADMIN_PASSWORD=your-secure-password
```

### Backup & Restore

```bash
# Backup
tar -czf backup-$(date +%Y%m%d).tar.gz ./storage/elasticsearch/

# Restore
docker compose down
tar -xzf backup-YYYYMMDD.tar.gz
docker compose up -d
```

---

## Configuration Reference

Complete `config.yaml` structure:

```yaml
# Email mapping (recommended)
email_mapping:
  "Person Name":
    - "email1@company.com"
    - "email2@company.com"

# Repositories
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

## Tech Stack

- **Docker Compose** - Container orchestration
- **Elasticsearch 8.17** - Data storage and search
- **Grafana** - Visualization
- **Python 3.12+** - Analysis scripts
- **uv** - Fast Python package manager (10-100x faster than pip)

---

## Philosophy

**Simple by default.** Two commands: `./install.sh` once, `./run.sh` daily.

**Safe to experiment.** Idempotent operations. Run `./run.sh` as often as you want.

**Data-driven decisions.** Base engineering choices on actual activity, not gut feelings.

**Privacy-first.** All data stays on your infrastructure. No external services.

---

## FAQ

**Q: Why not just use GitHub Insights?**  
A: GitHub Insights is per-repo. This is cross-repo, cross-team, with custom email mapping and file exclusions.

**Q: Does this work with GitLab/Bitbucket?**  
A: Yes. It analyzes local git repos. Doesn't matter where they're hosted.

**Q: Can I analyze private repos?**  
A: Yes. Clone them locally (with proper SSH keys), add to config, run `./run.sh`.

**Q: How much disk space do I need?**  
A: Depends on repo count/size. Budget ~100MB per 10k commits in Elasticsearch.

**Q: Can I run this on a server?**  
A: Yes. See Production section for security hardening.

**Q: What about monorepos?**  
A: Works fine. You might want custom file exclusions for generated code.

---

## Maintenance

### Regular Tasks

```bash
# Daily: update stats (automate via cron)
./run.sh

# Weekly: check for unmapped emails
python3 scripts/find_unmapped_emails.py config.yaml

# Monthly: backup data
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

## What's Next?

1. **Start small** - Analyze a few repos first
2. **Refine config** - Add email mappings as you discover them
3. **Automate** - Set up daily cron jobs
4. **Share insights** - Use dashboards in team meetings
5. **Customize** - Build dashboards for your specific needs

The goal: understand your engineering org better. Git Panorama gives you the data. You bring the insights.

---

*Built for engineering teams who value transparency and data-driven decisions.*

*Questions? Issues? PRs welcome.*
