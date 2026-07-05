# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2026-07-05

### Added
- New unified CLI command `abm` installed globally or locally under `/opt/autoniza-backup/bin/abm`.
- Subcommand `abm backup` for complete backups.
- Subcommand `abm restore` with interactive restore flows for PostgreSQL, MySQL, Redis, docker volumes, custom files, or everything.
- Subcommand `abm restore --snapshot <id>` and `--dry-run` options.
- Subcommand `abm snapshots` showing a table of backups.
- Subcommand `abm doctor` executing a battery of checks (Docker, Restic, Postgres, MySQL, Redis, Disk space, Cron, MinIO, binaries, etc.) and printing a health score.
- Subcommand `abm status` reporting server, backup, snapshot count, space, retention, and hook details.
- Subcommand `abm report` reporting previous backup history, durations, sizes, failure, and success rates.
- Subcommand `abm config` for viewing/editing backup.yaml and config.env.
- Subcommand `abm schedule` for managing cron jobs easily.
- Subcommand `abm update` with fetch, fast-forward validation, config preservation, and rollback backup.
- Verification pipeline using GitHub Actions (shellcheck, yamllint, markdownlint).
- Automated unit test suite under `tests/`.

### Changed
- Refactored `backup.sh`, `restore.sh`, `install.sh`, `update.sh`, and `uninstall.sh` to behave as wrappers around the `abm` CLI.
- Extracted and modularized backup, config loading, and execution logic into clean modules in `lib/`.
