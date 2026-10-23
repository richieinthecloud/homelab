#!/usr/bin/env bash
# Managed by Ansible (homelab/ansible/roles/host_metrics). Local edits will be overwritten.
#
# Writes host facts that node-exporter can't see on its own, in Prometheus text format,
# to a file node-exporter's textfile collector reads:
#   - OS updates waiting, and how many are security updates
#   - whether a reboot is required (e.g. after a kernel update)
#   - on the control-plane: age of the newest etcd snapshot
#   - expiry dates of the k3s certificates on this node
# Run every 15 minutes by homelab-host-metrics.timer. Changes nothing on the system.
set -euo pipefail

OUT_DIR="${OUT_DIR:-/var/lib/node_exporter/textfile}"
K3S_DIR="${K3S_DIR:-/var/lib/rancher/k3s}"
REBOOT_FILE="${REBOOT_FILE:-/var/run/reboot-required}"

out="$OUT_DIR/homelab_host.prom"
tmp="$(mktemp "$OUT_DIR/.homelab_host.prom.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

metric() { # name, type, help
  printf '# HELP %s %s\n# TYPE %s %s\n' "$1" "$3" "$1" "$2"
}

{
  # Simulated upgrade (-s): lists what would be installed, installs nothing.
  sim="$(apt-get -s -o Debug::NoLocking=true dist-upgrade 2>/dev/null || true)"
  metric homelab_apt_upgrades_pending gauge "Packages with an upgrade waiting."
  echo "homelab_apt_upgrades_pending $(grep -c '^Inst ' <<<"$sim" || true)"
  metric homelab_apt_security_upgrades_pending gauge "Waiting upgrades that come from the security pocket."
  echo "homelab_apt_security_upgrades_pending $(grep '^Inst ' <<<"$sim" | grep -c -- '-security' || true)"

  metric homelab_reboot_required gauge "1 if the OS says a reboot is needed (e.g. new kernel)."
  if [ -f "$REBOOT_FILE" ]; then echo "homelab_reboot_required 1"; else echo "homelab_reboot_required 0"; fi

  # Only the control-plane has etcd snapshots. 0 = no snapshot at all (the alert treats it as stale).
  snapdir="$K3S_DIR/server/db/snapshots"
  if [ -d "$snapdir" ]; then
    newest="$(find "$snapdir" -maxdepth 1 -type f -printf '%T@\n' | sort -n | tail -n1 | cut -d. -f1)"
    metric homelab_etcd_snapshot_newest_timestamp_seconds gauge "When the newest local etcd snapshot was written."
    echo "homelab_etcd_snapshot_newest_timestamp_seconds ${newest:-0}"
    metric homelab_etcd_snapshot_files gauge "Local etcd snapshot files kept on this node."
    echo "homelab_etcd_snapshot_files $(find "$snapdir" -maxdepth 1 -type f | wc -l)"
  fi

  # k3s renews certificates when it starts and they're close to expiry; this catches a
  # node that hasn't restarted k3s in a long time.
  metric homelab_k3s_cert_expiry_timestamp_seconds gauge "When each k3s certificate on this node expires."
  for crt in "$K3S_DIR"/server/tls/*.crt "$K3S_DIR"/agent/*.crt; do
    [ -f "$crt" ] || continue
    end="$(openssl x509 -enddate -noout -in "$crt" 2>/dev/null | cut -d= -f2)" || continue
    ts="$(date -d "$end" +%s 2>/dev/null)" || continue
    echo "homelab_k3s_cert_expiry_timestamp_seconds{cert=\"${crt#"$K3S_DIR"/}\"} $ts"
  done
} > "$tmp"

# Write-then-rename, so node-exporter never reads a half-written file.
chmod 0644 "$tmp"
mv "$tmp" "$out"
trap - EXIT