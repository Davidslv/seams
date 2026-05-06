# frozen_string_literal: true

require "seams/events"

module Seams
  # Tracks every event name that an engine has declared it emits, along
  # with the engine that owns it. Acts as the single source of truth for
  # `bin/rails seams:list` and prevents two engines from claiming the
  # same event name.
  module EventRegistry
    @registry = {}
    @mutex    = Mutex.new

    class << self
      def register(name, emitted_by:)
        Events.assert_valid_name!(name)
        name = name.to_s

        @mutex.synchronize do
          existing = @registry[name]

          if existing && existing != emitted_by
            raise Events::DuplicateEventError,
                  "Event #{name.inspect} already registered by #{existing.inspect}; " \
                  "cannot also be registered by #{emitted_by.inspect}"
          end

          @registry[name] = emitted_by
        end
      end

      def registered?(name)
        @registry.key?(name.to_s)
      end

      def emitter_of(name)
        @registry[name.to_s]
      end

      def all
        @registry.dup
      end

      def reset!
        @mutex.synchronize { @registry.clear }
      end
    end
  end
end
