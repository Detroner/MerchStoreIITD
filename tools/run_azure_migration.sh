#!/usr/bin/env bash
set -euo pipefail

SUB=92e0da8a-a2bd-4791-8b9b-412bf60101b1
RG=my-iitd-rg
PG=merchstore-pg-central
KV=merchstore-iitd-kv-2026
RULE="manual-migration-$(date +%s)"
cleanup(){
  az postgres flexible-server firewall-rule delete --subscription "$SUB" --resource-group "$RG" --server-name "$PG" --name "$RULE" --yes -o none || true
}
trap cleanup EXIT

IP=$(curl -fsS https://api.ipify.org)
az postgres flexible-server firewall-rule create --subscription "$SUB" --resource-group "$RG" --server-name "$PG" --name "$RULE" --start-ip-address "$IP" --end-ip-address "$IP" -o none
export DATABASE_URL="$(az keyvault secret show --subscription "$SUB" --vault-name "$KV" --name DATABASE-URL --query value -o tsv)"
export DATABASE_SSL="$(az keyvault secret show --subscription "$SUB" --vault-name "$KV" --name DATABASE-SSL --query value -o tsv)"
npm run db:migrate
