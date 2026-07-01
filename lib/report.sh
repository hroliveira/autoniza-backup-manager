#!/usr/bin/env bash
set -Eeuo pipefail

[[ -n "${ABM_REPORT_LOADED:-}" ]] && return 0
ABM_REPORT_LOADED=1
# ═══════════════════════════════════════════════════════════════
# Autoniza Backup Manager - Gerador de Relatórios
# ═══════════════════════════════════════════════════════════════

# ── Gerar relatório em texto simples ──────────────────────────
generate_text_report() {
  local output_file="$1"
  local status="$2"
  local snapshot="$3"
  local duration="$4"
  local details="$5"

  cat > "$output_file" <<EOF
╔══════════════════════════════════════════════════════════════╗
║         Autoniza Backup Manager - Relatório de Backup       ║
╚══════════════════════════════════════════════════════════════╝

Servidor:       $(yq eval '.server.name' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo "unknown")
Ambiente:       $(yq eval '.server.environment' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo "unknown")
Data:           $(date '+%Y-%m-%d %H:%M:%S')
Status:         ${status}
Snapshot:       ${snapshot}
Duração:        ${duration}

── Detalhes ────────────────────────────────────────────────
${details}

── Retenção Aplicada ──────────────────────────────────────
  Daily:    $(yq eval '.retention.daily' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo "?")
  Weekly:   $(yq eval '.retention.weekly' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo "?")
  Monthly:  $(yq eval '.retention.monthly' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo "?")

─────────────────────────────────────────────────────────────
Relatório gerado automaticamente pelo Autoniza Backup Manager.
EOF

  log_success "Relatório texto gerado: $output_file"
}

# ── Gerar relatório em HTML ───────────────────────────────────
generate_html_report() {
  local output_file="$1"
  local status="$2"
  local snapshot="$3"
  local duration="$4"
  local details="$5"

  local server_name
  local server_env
  server_name="$(yq eval '.server.name' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo "unknown")"
  server_env="$(yq eval '.server.environment' "${BACKUP_ROOT}/config/backup.yaml" 2>/dev/null || echo "unknown")"

  local status_color
  local status_icon
  if [[ "$status" == "success" ]]; then
    status_color="#22c55e"
    status_icon="✅"
  else
    status_color="#ef4444"
    status_icon="❌"
  fi

  cat > "$output_file" <<HTMLEOF
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Relatório de Backup - ${server_name}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #f8fafc;
      color: #1e293b;
      padding: 2rem;
      line-height: 1.6;
    }
    .container {
      max-width: 800px;
      margin: 0 auto;
    }
    .header {
      background: linear-gradient(135deg, #1e293b, #334155);
      color: white;
      padding: 2rem;
      border-radius: 12px;
      margin-bottom: 1.5rem;
    }
    .header h1 { font-size: 1.5rem; margin-bottom: 0.5rem; }
    .status-badge {
      display: inline-block;
      padding: 0.25rem 0.75rem;
      background: ${status_color};
      color: white;
      border-radius: 999px;
      font-size: 0.875rem;
      font-weight: 600;
    }
    .grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1rem;
      margin-bottom: 1.5rem;
    }
    .card {
      background: white;
      padding: 1.25rem;
      border-radius: 8px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    }
    .card h3 {
      font-size: 0.75rem;
      text-transform: uppercase;
      color: #64748b;
      margin-bottom: 0.25rem;
      letter-spacing: 0.05em;
    }
    .card .value { font-size: 1.125rem; font-weight: 600; }
    .details {
      background: white;
      padding: 1.25rem;
      border-radius: 8px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1);
      margin-bottom: 1.5rem;
    }
    .details pre {
      background: #f1f5f9;
      padding: 1rem;
      border-radius: 6px;
      font-size: 0.875rem;
      overflow-x: auto;
      margin-top: 0.75rem;
    }
    .footer {
      text-align: center;
      font-size: 0.75rem;
      color: #94a3b8;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>${status_icon} Autoniza Backup Manager</h1>
      <p>Relatório de Backup - ${server_name}</p>
      <span class="status-badge">${status}</span>
    </div>
    <div class="grid">
      <div class="card">
        <h3>Servidor</h3>
        <div class="value">${server_name}</div>
      </div>
      <div class="card">
        <h3>Ambiente</h3>
        <div class="value">${server_env}</div>
      </div>
      <div class="card">
        <h3>Snapshot</h3>
        <div class="value">${snapshot}</div>
      </div>
      <div class="card">
        <h3>Duração</h3>
        <div class="value">${duration}</div>
      </div>
    </div>
    <div class="details">
      <h3>Detalhes</h3>
      <pre>${details}</pre>
    </div>
    <div class="footer">
      Relatório gerado em $(date '+%Y-%m-%d %H:%M:%S') pelo Autoniza Backup Manager
    </div>
  </div>
</body>
</html>
HTMLEOF

  log_success "Relatório HTML gerado: $output_file"
}
