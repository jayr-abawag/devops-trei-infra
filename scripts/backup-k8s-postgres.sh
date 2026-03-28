#!/bin/bash

# P2-POS PostgreSQL Backup Script for Kubernetes
#
# This script creates backups of the K8s PostgreSQL database and can restore from backups.
#
# Usage:
#   ./backup-k8s-postgres.sh [command]
#
# Commands:
#   backup   - Create a new backup (default)
#   restore  - Restore from a backup
#   list     - List all available backups
#   schedule - Set up automated backups with cron
#
# Examples:
#   ./backup-k8s-postgres.sh backup
#   ./backup-k8s-postgres.sh restore backup-20250327-120000.sql
#   ./backup-k8s-postgres.sh list

set -e

# Configuration
NAMESPACE="mc-pos"
POSTGRES_POD_LABEL="app=pos-postgres"
BACKUP_DIR="./backups/postgres"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="backup-${TIMESTAMP}.sql"
RETENTION_DAYS=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi

    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_error "Please configure kubectl to connect to your cluster"
        exit 1
    fi

    # Check if PostgreSQL pod is running
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$POSTGRES_POD_LABEL" -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")

    if [ -z "$POD_NAME" ]; then
        log_error "PostgreSQL pod not found in namespace $NAMESPACE"
        exit 1
    fi

    POD_STATUS=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath="{.status.phase}")

    if [ "$POD_STATUS" != "Running" ]; then
        log_error "PostgreSQL pod is not running (status: $POD_STATUS)"
        exit 1
    fi

    log_info "PostgreSQL pod found: $POD_NAME"
}

# Get database credentials from secrets
get_db_credentials() {
    DB_USER=$(kubectl get secret pos-secrets -n "$NAMESPACE" -o jsonpath="{.data.POSTGRES_USER}" | base64 -d)
    DB_NAME=$(kubectl get secret pos-secrets -n "$NAMESPACE" -o jsonpath="{.data.POSTGRES_DB}" | base64 -d)
    DB_PASSWORD=$(kubectl get secret pos-secrets -n "$NAMESPACE" -o jsonpath="{.data.POSTGRES_PASSWORD}" | base64 -d)
}

# Create backup
create_backup() {
    log_info "Creating backup..."

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    # Get pod name
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$POSTGRES_POD_LABEL" -o jsonpath="{.items[0].metadata.name}")

    # Get database credentials
    get_db_credentials

    # Create backup
    log_info "Backing up database: $DB_NAME"
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- pg_dump -U "$DB_USER" "$DB_NAME" --clean --if-exists > "$BACKUP_DIR/$BACKUP_FILE"

    # Compress backup
    gzip "$BACKUP_DIR/$BACKUP_FILE"
    BACKUP_FILE="${BACKUP_FILE}.gz"

    # Get backup size
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)

    log_info "Backup created successfully: $BACKUP_DIR/$BACKUP_FILE ($BACKUP_SIZE)"

    # Clean up old backups
    cleanup_old_backups
}

# Restore from backup
restore_backup() {
    local backup_file=$1

    if [ -z "$backup_file" ]; then
        log_error "Please specify a backup file to restore"
        echo "Usage: $0 restore <backup-file>"
        exit 1
    fi

    if [ ! -f "$backup_file" ]; then
        # Check if it's in the backup directory
        if [ -f "$BACKUP_DIR/$backup_file" ]; then
            backup_file="$BACKUP_DIR/$backup_file"
        else
            log_error "Backup file not found: $backup_file"
            exit 1
        fi
    fi

    log_warn "WARNING: This will replace all data in the database!"
    read -p "Are you sure you want to continue? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Restore cancelled"
        exit 0
    fi

    log_info "Restoring from backup: $backup_file"

    # Get pod name
    POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l "$POSTGRES_POD_LABEL" -o jsonpath="{.items[0].metadata.name}")

    # Get database credentials
    get_db_credentials

    # Decompress if needed
    if [[ $backup_file == *.gz ]]; then
        log_info "Decompressing backup..."
        gunzip -c "$backup_file" | kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- psql -U "$DB_USER" "$DB_NAME"
    else
        kubectl exec -i -n "$NAMESPACE" "$POD_NAME" -- psql -U "$DB_USER" "$DB_NAME" < "$backup_file"
    fi

    log_info "Database restored successfully"
}

# List available backups
list_backups() {
    log_info "Available backups in $BACKUP_DIR:"

    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR)" ]; then
        log_warn "No backups found"
        exit 0
    fi

    printf "%-40s %-15s %-15s\n" "Backup File" "Size" "Date"
    printf "%-40s %-15s %-15s\n" "------------" "----" "----"

    for backup in "$BACKUP_DIR"/backup-*.sql*; do
        if [ -f "$backup" ]; then
            filename=$(basename "$backup")
            size=$(du -h "$backup" | cut -f1)
            date=$(stat -c %y "$backup" | cut -d' ' -f1,2 | cut -d'.' -f1)
            printf "%-40s %-15s %-15s\n" "$filename" "$size" "$date"
        fi
    done
}

# Clean up old backups
cleanup_old_backups() {
    log_info "Cleaning up backups older than $RETENTION_DAYS days..."

    if [ ! -d "$BACKUP_DIR" ]; then
        return
    fi

    # Find and delete old backups
    old_backups=$(find "$BACKUP_DIR" -name "backup-*.sql*" -type f -mtime +$RETENTION_DAYS)

    if [ -n "$old_backups" ]; then
        echo "$old_backups" | while read -r old_backup; do
            log_info "Deleting old backup: $(basename "$old_backup")"
            rm "$old_backup"
        done
    else
        log_info "No old backups to clean up"
    fi
}

# Set up automated backups with cron
schedule_backups() {
    log_info "Setting up automated backups..."

    # Get script directory
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    SCRIPT_PATH="$SCRIPT_DIR/backup-k8s-postgres.sh"

    # Create cron job for daily backups at 2 AM
    CRON_JOB="0 2 * * * $SCRIPT_PATH backup >> $BACKUP_DIR/backup-cron.log 2>&1"

    log_info "To enable automated backups, add the following line to your crontab:"
    echo ""
    echo "$CRON_JOB"
    echo ""
    log_info "To edit crontab, run: crontab -e"
    log_info "To list cron jobs, run: crontab -l"

    # Ask if user wants to add it now
    read -p "Would you like to add this cron job now? (yes/no): " confirm

    if [ "$confirm" = "yes" ]; then
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        log_info "Cron job added successfully"
    else
        log_info "Cron job not added. You can add it manually later."
    fi
}

# Main script logic
main() {
    local command=${1:-backup}

    case $command in
        backup)
            check_prerequisites
            create_backup
            ;;
        restore)
            check_prerequisites
            restore_backup "$2"
            ;;
        list)
            list_backups
            ;;
        schedule)
            schedule_backups
            ;;
        cleanup)
            check_prerequisites
            cleanup_old_backups
            ;;
        *)
            echo "P2-POS PostgreSQL Backup Script for Kubernetes"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  backup [file]    - Create a new backup (default)"
            echo "  restore <file>   - Restore from a backup file"
            echo "  list            - List all available backups"
            echo "  schedule        - Set up automated backups with cron"
            echo "  cleanup         - Clean up old backups (older than $RETENTION_DAYS days)"
            echo ""
            echo "Examples:"
            echo "  $0 backup"
            echo "  $0 restore backup-20250327-120000.sql.gz"
            echo "  $0 list"
            echo "  $0 schedule"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
