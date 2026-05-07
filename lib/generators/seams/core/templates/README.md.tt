# Core

> Foundation primitives every Seams engine can build on. Concerns for
> auditing, soft delete, slugs, multi-tenancy, plus shared services
> and validators.

## Events emitted

| Event name | Payload | Emitted when |
| --- | --- | --- |
| `record.audited.core` | `{ action:, type:, id:, actor_id: }` | `Core::Auditable` records an entry on create/update/destroy |

## Events consumed

This engine does not subscribe to any other engine's events.

## Exposed concerns

| Concern                                | Purpose                                              |
| ---                                    | ---                                                  |
| `Core::Auditable`                      | Records audit entries for the model on CRUD.         |
| `Core::SoftDeletable`                  | `deleted_at` tombstone + default scope.              |
| `Core::Sluggable`                      | Auto-generated URL slug with collision suffixing.    |
| `Core::TenantScoped`                   | Auto-scopes records to `Core::Current.team`.         |
| `Core::HasCurrentAttributes`           | Populates `Core::Current` on every request.          |

## Services + validators

| Symbol                              | Purpose                                                                   |
| ---                                 | ---                                                                       |
| `Core::EventPublisher.publish`      | Wraps `Seams::Events::Publisher.publish` and adds actor/team/request id. |
| `Core::EmailFormatValidator`        | Stricter email-shape validator (`validates :email, email_format: true`). |
| `Core::Current` (CurrentAttributes) | Per-request `user`, `team`, `request_id`.                                |

## Mounting

The engine has no routes — it ships shared code, not endpoints. The
generator mounts at `/` for completeness; you can remove the mount
line if you don't need any routing entry point.

## Running the specs

```bash
bin/rails seams:test[core]
```
