# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Multi-file report structure with task-specific folders (`docs/reports/A01/`, `A02/`, `B01/`)
- Centralized GenAI documentation in `prompt_logs/` directory
- Comprehensive repository structure documentation in README.md
- Strategic prompt log templates with detailed GenAI usage tracking
- Cross-reference system between reports and prompt logs

### Changed
- Migrated from single-file to multi-part report structure (main + part01/part02/part03)
- Updated Cursor rules to use proper `.mdc` format (removed non-working `.rule` files)
- Enhanced documentation style enforcement with multi-file guidelines
- Reorganized deliverables mapping to reflect new structure


## [2025-01-08] - Initial Setup

### Added
- Initial project setup: Cursor rules and planning scaffolds
- Memory Bank structure with core files (projectbrief, productContext, techContext, etc.)
- Basic planning framework (backlog, roadmap, risks, ADR structure)
- Engineering standards for Terraform and Ansible
