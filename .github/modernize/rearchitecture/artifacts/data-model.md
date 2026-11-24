# Data Model

## Persistence
- Drift database file: `service_reminder.sqlite`, under the application documents directory.
- Schema version: 3.
- Foreign keys enabled in `beforeOpen`.

## Customers
Source: `service_reminder/lib/data/local/tables.dart:3`.

| Field | Drift type | Constraints |
|---|---|---|
| id | Text | primary key |
| name | Text | required |
| phone | Text | required |
| address | Text | required |
| installationDate | DateTime | required |
| nextDueDate | DateTime | required |
| createdAt | DateTime | required |
| updatedAt | DateTime | required |
| reminderIntervalMonths | Int | nullable |

Date-only fields are normalized to UTC midnight. `createdAt` and `updatedAt` are UTC instants.

## ServiceRecords
Source: `service_reminder/lib/data/local/tables.dart:22`.

| Field | Drift type | Constraints |
|---|---|---|
| id | Text | primary key |
| customerId | Text | foreign key to Customers.id |
| serviceDate | DateTime | required |
| whatChanged | Text | required |
| createdAt | DateTime | required |

## Relationship
- One `Customer` has many `ServiceRecord` rows.
- Service records are deleted before customers are deleted.
- No explicit cascade-delete rule is declared; repository code performs child deletion explicitly.

## Key entity summary
- Customer: base identity and next service due state.
- ServiceRecord: historical service event used to recompute next due state.
- CustomerWithHistory: in-memory aggregate combining one Customer and descending service records.

