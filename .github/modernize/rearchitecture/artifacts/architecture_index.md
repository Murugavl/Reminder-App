# Architecture Index

## Implementation Guide

This index is not the full contract. Do not implement from this file alone; follow the artifact paths below.

### Global artifacts
- `unit_graph.yaml`: unit boundaries, triggers, signatures, dynamic entry points, and shared refs.
- `project-structure.md`: repository layout and functional domains.
- `tech-stack.md`: existing dependencies, languages, runtimes, and build constraints.
- `data-model.md`: existing Drift entities and relationships.
- `wire_contracts.yaml`: database, backup, and external contract shapes. Filter by `unit`.
- `shared_modules.yaml`: shared repository/service modules. Filter by `used_by_units`.
- `cross_unit_state.yaml`: implicit state flows. Filter by `writer.unit` or `reader.unit`.

### Unit: home
- external trigger: app launch / MaterialApp.home
- must read:
  - `units/home/behavior.yaml`
  - `units/home/bindings.yaml`
  - `units/home/unit_decomposition.yaml`
- relevant global rows: wire contracts where `unit: home` or `global`; shared customer-repository row; cross-unit provider flow.
- before DONE: list read artifacts; implement must-preserve list; report unresolved runtime verification; provide test/build evidence.

### Unit: add-customer
- external trigger: Add Customer page
- must read:
  - `units/add-customer/behavior.yaml`
  - `units/add-customer/bindings.yaml`
  - `units/add-customer/unit_decomposition.yaml`
- relevant global rows: customer-repository shared module; local database contract.
- before DONE: list read artifacts; implement must-preserve list; report unresolved contracts; provide test/build evidence.

### Unit: customer-detail
- external trigger: Customer detail page / notification payload
- must read:
  - `units/customer-detail/behavior.yaml`
  - `units/customer-detail/bindings.yaml`
  - `units/customer-detail/unit_decomposition.yaml`
- relevant global rows: customer-repository shared module; notification payload and provider invalidation flows.
- before DONE: list read artifacts; verify all service CRUD and due recomputation contracts; report unresolved runtime checks; provide test/build evidence.

### Unit: edit-customer
- external trigger: Edit Customer page
- must read:
  - `units/edit-customer/behavior.yaml`
  - `units/edit-customer/bindings.yaml`
  - `units/edit-customer/unit_decomposition.yaml`
- relevant global rows: customer-repository shared module.
- before DONE: list read artifacts; preserve update and invalidation behavior; report unresolved contracts; provide test/build evidence.

### Unit: settings
- external trigger: Settings page
- must read:
  - `units/settings/behavior.yaml`
  - `units/settings/bindings.yaml`
  - `units/settings/unit_decomposition.yaml`
- relevant global rows: backup-service shared module; Google Drive wire contract; preference runtime config.
- before DONE: list read artifacts; verify sign-in, backup, restore, scheduling, and preference contracts; report unresolved Google auth runtime checks; provide test/build evidence.

### Unit: restore-backup
- external trigger: Restore from Backup page
- must read:
  - `units/restore-backup/behavior.yaml`
  - `units/restore-backup/bindings.yaml`
  - `units/restore-backup/unit_decomposition.yaml`
- relevant global rows: backup-service shared module; Google Drive contract; local database contract.
- before DONE: list read artifacts; verify confirmation and destructive transaction semantics; report unresolved runtime checks; provide test/build evidence.

### Unit: overdue-reminder-job
- external trigger: 24-hour Workmanager task
- must read:
  - `units/overdue-reminder-job/behavior.yaml`
  - `units/overdue-reminder-job/bindings.yaml`
  - `units/overdue-reminder-job/unit_decomposition.yaml`
- relevant global rows: customer-repository shared module; notification payload flow; local database contract.
- before DONE: list read artifacts; verify callback discoverability, due cutoff, notification payload, and sound preference; provide runtime/test/build evidence.

### Unit: weekly-backup-job
- external trigger: 7-day Workmanager task
- must read:
  - `units/weekly-backup-job/behavior.yaml`
  - `units/weekly-backup-job/bindings.yaml`
  - `units/weekly-backup-job/unit_decomposition.yaml`
- relevant global rows: backup-service shared module; Google Drive contract; local database contract.
- before DONE: list read artifacts; verify soft background auth failure, snapshot shape, and database closure; provide runtime/test/build evidence.
