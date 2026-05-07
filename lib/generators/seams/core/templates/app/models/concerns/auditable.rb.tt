# frozen_string_literal: true

require "active_support/concern"

module Core
  # Mix into any model to get an audit log entry on every
  # create/update/destroy. Records the actor from Current.user and
  # the changed attributes for updates.
  #
  #   class Article < ApplicationRecord
  #     include Core::Auditable
  #   end
  module Auditable
    extend ActiveSupport::Concern

    included do
      has_many :audit_logs, class_name: "Core::AuditLog",
                            as: :auditable, dependent: :nullify

      # after_commit (not after_create / after_update / after_destroy)
      # so the publish doesn't fire inside the host model's open
      # transaction. Subscribers run synchronously; an in-transaction
      # publish lets a slow subscriber hold the table lock.
      after_commit :record_audit_create,  on: :create
      after_commit :record_audit_update,  on: :update
      after_commit :record_audit_destroy, on: :destroy
    end

    private

    def record_audit_create
      record_audit("create", attributes_snapshot)
    end

    def record_audit_update
      changed = saved_changes.transform_values(&:last)
      return if changed.empty?

      record_audit("update", changed)
    end

    def record_audit_destroy
      record_audit("destroy", attributes_snapshot)
    end

    def record_audit(action, payload)
      Core::AuditLog.create!(
        action:         action,
        auditable_type: self.class.name,
        auditable_id:   id,
        actor_id:       Core::Current.user&.id,
        payload:        payload
      )
      Seams::Events::Publisher.publish(
        "record.audited.core",
        action: action, type: self.class.name, id: id, actor_id: Core::Current.user&.id
      )
    end

    def attributes_snapshot
      attributes.except("created_at", "updated_at")
    end
  end
end
