# frozen_string_literal: true

require "active_support/concern"

module Core
  # Tombstone-style soft delete. Sets `deleted_at` instead of actually
  # destroying the row, and adds a default scope that hides deleted
  # records. Use `unscoped` to query them.
  #
  #   class Article < ApplicationRecord
  #     include Core::SoftDeletable
  #   end
  #
  # Requires a `deleted_at` timestamp column on the model's table.
  module SoftDeletable
    extend ActiveSupport::Concern

    included do
      default_scope { where(deleted_at: nil) }

      scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
      scope :with_deleted, -> { unscoped }
    end

    def soft_delete!
      update!(deleted_at: Time.current)
    end

    def restore!
      update!(deleted_at: nil)
    end

    def deleted?
      deleted_at.present?
    end
  end
end
