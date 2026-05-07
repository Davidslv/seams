# frozen_string_literal: true

require "active_support/concern"

module Core
  # Auto-generates a URL slug from a configured source attribute on
  # create. Appends a numeric suffix on collision (acme, acme-2,
  # acme-3, ...) so users see "creating Acme" succeed even when the
  # name is taken.
  #
  #   class Team < ApplicationRecord
  #     include Core::Sluggable
  #     sluggable_from :name
  #   end
  module Sluggable
    extend ActiveSupport::Concern

    class_methods do
      def sluggable_from(attribute)
        @slug_source = attribute
      end

      def slug_source
        @slug_source || :name
      end
    end

    included do
      validates :slug, presence: true, uniqueness: true,
                       format: { with: /\A[a-z0-9-]+\z/ }
      before_validation :assign_slug, on: :create
    end

    private

    def assign_slug
      return if slug.present?

      base    = slug_base
      candidate = base
      counter = 2
      while self.class.where.not(id: id).exists?(slug: candidate)
        candidate = "#{base}-#{counter}"
        counter += 1
      end
      self.slug = candidate
    end

    def slug_base
      send(self.class.slug_source).to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")
    end
  end
end
