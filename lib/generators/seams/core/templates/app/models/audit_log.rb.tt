# frozen_string_literal: true

module Core
  # Records create/update/destroy events for any model that includes
  # Core::Auditable. Schema is intentionally polymorphic so the audit
  # table can serve every engine.
  class AuditLog < ApplicationRecord
    self.table_name = "core_audit_logs"

    ACTIONS = %w[create update destroy].freeze

    belongs_to :auditable, polymorphic: true, optional: true

    validates :action, inclusion: { in: ACTIONS }

    scope :for, ->(record) { where(auditable_type: record.class.name, auditable_id: record.id) }
    scope :recent, -> { order(created_at: :desc) }
  end
end
