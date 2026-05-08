# frozen_string_literal: true

require "seams/events/publisher"
require "seams/events/adapters/active_support"
require "seams/event_registry"

RSpec.describe Seams::Events::Publisher do
  let(:adapter) { Seams::Events::Adapters::ActiveSupport.new }

  before do
    allow(described_class).to receive(:adapter).and_return(adapter)
    described_class.reset!
    allow(described_class).to receive(:adapter).and_return(adapter)
    Seams::EventRegistry.reset!
    Seams::EventRegistry.register("subscription.created.billing", emitted_by: "Billing")
  end

  describe ".publish" do
    it "delegates to the configured adapter" do
      received = nil
      adapter.subscribe("subscription.created.billing") { |_, _, _, _, p| received = p }

      described_class.publish("subscription.created.billing", id: 42)

      expect(received).to eq(id: 42)
    end

    it "raises if the event has not been registered" do
      expect do
        described_class.publish("ghost.event.unknown", {})
      end.to raise_error(Seams::Events::UnregisteredEventError, /ghost\.event\.unknown/)
    end

    it "rejects names that don't follow the resource.action.engine convention" do
      expect do
        described_class.publish("badly_named_event", {})
      end.to raise_error(Seams::Events::InvalidEventNameError, /resource\.action\.engine/)
    end
  end

  describe ".subscribe" do
    it "wraps the block so the engine receives the payload directly" do
      payload_seen = nil
      described_class.subscribe("subscription.created.billing") { |p| payload_seen = p }
      described_class.publish("subscription.created.billing", id: 7)

      expect(payload_seen).to eq(id: 7)
    end

    it "tracks every subscription so they can be inspected later" do
      described_class.subscribe("subscription.created.billing") { :noop }
      expect(described_class.subscriptions).to include("subscription.created.billing")
    end

    it "rejects subscriptions to invalid event names" do
      expect do
        described_class.subscribe("not-a-valid-event") { :noop }
      end.to raise_error(Seams::Events::InvalidEventNameError)
    end
  end

  describe ".orphan_subscriptions" do
    it "returns subscriptions that no engine has registered as an emitted event" do
      described_class.subscribe("subscription.created.billing") { :noop }   # registered
      described_class.subscribe("user.signed_up.atuh")          { :noop }   # typo

      expect(described_class.orphan_subscriptions).to eq(["user.signed_up.atuh"])
    end

    it "returns an empty array when every subscription has a registered emitter" do
      described_class.subscribe("subscription.created.billing") { :noop }
      expect(described_class.orphan_subscriptions).to be_empty
    end
  end

  describe ".attach_once" do
    it "subscribes the first time and returns a truthy handle" do
      handle = described_class.attach_once(:test_key, "subscription.created.billing") { :noop }
      expect(handle).not_to be_nil
    end

    it "is idempotent across repeated calls with the same (key, event_name)" do
      received = []
      described_class.attach_once(:test_key, "subscription.created.billing") { |p| received << p }
      described_class.attach_once(:test_key, "subscription.created.billing") { |p| received << p }
      described_class.attach_once(:test_key, "subscription.created.billing") { |p| received << p }

      described_class.publish("subscription.created.billing", id: 1)

      expect(received).to eq([{ id: 1 }]) # not three callbacks, despite three attach_once calls
    end

    it "tracks attach state on Publisher itself, not on the subscriber class — so Rails autoreload doesn't double-subscribe" do
      described_class.attach_once(:test_key, "subscription.created.billing") { :noop }
      expect(described_class.attached_keys).to include([:test_key, "subscription.created.billing"])
    end
  end

  describe ".attach_class" do
    # Replaces +AttachClassSubscriberFixture+ with a brand-new class
    # object whose +handle+ method records the supplied version label.
    # Used to simulate Rails autoreload — calling it twice rebinds the
    # constant the way the autoloader would when the file changes.
    def stub_subscriber_recording(log, version_label:)
      stub_const("AttachClassSubscriberFixture", Class.new do
        define_singleton_method(:handle) { |_payload| log << version_label }
      end)
    end

    it "rejects a non-String class_name so callers don't accidentally capture a stale reference" do
      stub_class = Class.new
      expect do
        described_class.attach_class(:test_key, "subscription.created.billing",
                                     class_name: stub_class, method_name: :call)
      end.to raise_error(ArgumentError, /String/)
    end

    it "is idempotent on (key, event_name) like attach_once" do
      stub_const("AttachClassSubscriberFixture", Class.new do
        @received = []
        class << self
          attr_reader :received

          def handle(payload)
            @received << payload
          end
        end
      end)

      3.times do
        described_class.attach_class(:test_key, "subscription.created.billing",
                                     class_name: "AttachClassSubscriberFixture", method_name: :handle)
      end

      described_class.publish("subscription.created.billing", id: 1)
      expect(AttachClassSubscriberFixture.received).to eq([{ id: 1 }])
    end

    it "dispatches to a private class method so subscribers can keep handlers off their public surface" do
      stub_const("AttachClassSubscriberFixture", Class.new do
        @last_payload = nil
        class << self
          attr_reader :last_payload

          private

          def secret_handler(payload)
            @last_payload = payload
          end
        end
      end)

      described_class.attach_class(:private_key, "subscription.created.billing",
                                   class_name: "AttachClassSubscriberFixture", method_name: :secret_handler)
      described_class.publish("subscription.created.billing", id: 99)

      expect(AttachClassSubscriberFixture.last_payload).to eq(id: 99)
    end

    # Regression for the highest-impact dev-experience bug surfaced by
    # the boundary audit (see commit ada6438): a block passed to
    # +attach_once+ closes over the subscriber class object as it was
    # at boot, so when Rails autoreload swaps in a fresh class object
    # under the same constant, the OLD code keeps firing forever.
    #
    # +attach_class+ stores the class NAME (a String) and re-resolves
    # +Object.const_get+ on every dispatch. We simulate Rails autoreload
    # by binding the constant to a fresh class with a different handler
    # body, then publishing — the new behaviour MUST run.
    it "survives Rails autoreload — a constant reassignment routes the next event to the freshly loaded class" do
      versions_seen = []
      stub_subscriber_recording(versions_seen, version_label: :v1)
      described_class.attach_class(:reload_key, "subscription.created.billing",
                                   class_name: "AttachClassSubscriberFixture", method_name: :handle)
      described_class.publish("subscription.created.billing", id: 1)

      # Same constant, brand-new class object — exactly what Rails
      # autoloading does when the file changes on disk.
      stub_subscriber_recording(versions_seen, version_label: :v2)
      described_class.publish("subscription.created.billing", id: 2)

      expect(versions_seen).to eq(%i[v1 v2])
    end

    it "tracks attach state on Publisher so it shares the attached_keys ledger with attach_once" do
      stub_const("AttachClassSubscriberFixture", Class.new do
        def self.handle(_payload); end
      end)

      described_class.attach_class(:ledger_key, "subscription.created.billing",
                                   class_name: "AttachClassSubscriberFixture", method_name: :handle)
      expect(described_class.attached_keys).to include([:ledger_key, "subscription.created.billing"])
    end
  end
end
