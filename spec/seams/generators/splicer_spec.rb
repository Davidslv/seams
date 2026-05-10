# frozen_string_literal: true

require "fileutils"
require "seams/generators/splicer"

RSpec.describe Seams::Generators::Splicer do
  let(:tmp_root) { File.expand_path("../../tmp/splicer_spec", __dir__) }
  let(:file_path) { File.join(tmp_root, "engine.rb") }

  before do
    FileUtils.rm_rf(tmp_root)
    FileUtils.mkdir_p(tmp_root)
  end

  after { FileUtils.rm_rf(tmp_root) }

  def write_file(content)
    File.write(file_path, content)
  end

  def file_contents
    File.read(file_path)
  end

  describe ".splice_after_marker" do
    let(:engine_with_events_marker) do
      <<~RUBY
        module Auth
          initializer "auth.register_events" do
            Seams::EventRegistry.register("identity.signed_up.auth", emitted_by: "Auth")
            # seams:insertion-point auth.engine.events
          end
        end
      RUBY
    end

    let(:routes_with_before_marker) do
      <<~RUBY
        module Auth
          # seams:insertion-point auth.routes.before_session
          resource :session
        end
      RUBY
    end

    let(:passkey_event_line) do
      "Seams::EventRegistry.register(\"identity.passkey_added.auth\", emitted_by: \"Auth\")\n"
    end

    it "inserts single-line content immediately after the marker" do
      write_file(engine_with_events_marker)

      result = described_class.splice_after_marker(
        file_path: file_path, marker: "auth.engine.events", content: passkey_event_line
      )

      expect(result.ok?).to be(true)
      expect(result.lines_added).to eq(1)
      expect(file_contents).to include(<<~SNIP)
        # seams:insertion-point auth.engine.events
            Seams::EventRegistry.register("identity.passkey_added.auth", emitted_by: "Auth")
      SNIP
    end

    it "inserts multi-line content with consistent indentation" do
      write_file(routes_with_before_marker)
      content = "resource :passkey_session do\n  post :challenge\nend\n"

      result = described_class.splice_after_marker(
        file_path: file_path, marker: "auth.routes.before_session", content: content
      )

      expect(result.ok?).to be(true)
      expect(result.lines_added).to eq(3)
      expect(file_contents).to include(<<~SNIP)
        # seams:insertion-point auth.routes.before_session
          resource :passkey_session do
            post :challenge
          end
      SNIP
    end

    it "is idempotent — re-splicing the same content is a no-op" do
      write_file("module Auth\n  # seams:insertion-point auth.engine.events\nend\n")

      first = described_class.splice_after_marker(
        file_path: file_path, marker: "auth.engine.events", content: passkey_event_line
      )
      second = described_class.splice_after_marker(
        file_path: file_path, marker: "auth.engine.events", content: passkey_event_line
      )

      expect(first).to have_attributes(ok?: true, lines_added: 1)
      expect(second).to have_attributes(ok?: true, lines_added: 0)
      expect(file_contents.scan("identity.passkey_added.auth").size).to eq(1)
    end

    it "auto-detects indentation from the marker line by default" do
      # Marker at 6-space indent — inside a register_events block.
      write_file(<<~RUBY)
        module Auth
          initializer "auth.register_events" do
            # seams:insertion-point auth.engine.events
          end
        end
      RUBY

      result = described_class.splice_after_marker(
        file_path: file_path,
        marker: "auth.engine.events",
        content: "Seams::EventRegistry.register(\"identity.passkey_added.auth\", emitted_by: \"Auth\")\n"
      )

      expect(result.ok?).to be(true)
      # The marker line itself is at 4-space indent in this file (under
      # `initializer ... do`); the splicer should match that.
      expect(file_contents).to match(/^    Seams::EventRegistry\.register/)
    end

    it "honours an explicit empty `indent:` to insert verbatim" do
      write_file(<<~RUBY)
        module Auth
            # seams:insertion-point auth.engine.events
        end
      RUBY

      result = described_class.splice_after_marker(
        file_path: file_path,
        marker: "auth.engine.events",
        content: "Seams::EventRegistry.register(\"foo\")\n",
        indent: ""
      )

      expect(result.ok?).to be(true)
      expect(file_contents).to match(/^Seams::EventRegistry\.register/)
    end

    it "returns ok?: false with a clear error when the marker is not found" do
      write_file(<<~RUBY)
        module Auth
          # no markers here
        end
      RUBY

      result = described_class.splice_after_marker(
        file_path: file_path,
        marker: "auth.engine.events",
        content: "anything\n"
      )

      expect(result.ok?).to be(false)
      expect(result.lines_added).to eq(0)
      expect(result.error).to include("auth.engine.events")
      expect(result.error).to include(file_path)
      # The file is untouched.
      expect(file_contents).to include("# no markers here")
    end

    it "returns ok?: false when the file does not exist" do
      result = described_class.splice_after_marker(
        file_path: File.join(tmp_root, "nope.rb"),
        marker: "auth.engine.events",
        content: "x\n"
      )

      expect(result.ok?).to be(false)
      expect(result.error).to include("file not found")
    end

    it "does not match a marker with a different name even when the prefix overlaps" do
      write_file(<<~RUBY)
        # seams:insertion-point auth.engine.events_extra
      RUBY

      result = described_class.splice_after_marker(
        file_path: file_path,
        marker: "auth.engine.events",
        content: "x\n"
      )

      expect(result.ok?).to be(false)
      expect(result.error).to include("auth.engine.events")
    end

    it "stays idempotent for snippets larger than the default 50-line window" do
      # Regression: with a fixed 50-line haystack, splicing a 60-line
      # snippet would re-fire on every run because the haystack was
      # smaller than the needle. The window now grows to fit the
      # prepared content.
      write_file("# seams:insertion-point auth.engine.events\nend\n")
      content = (1..60).map { |i| "line_#{i}\n" }.join

      first = described_class.splice_after_marker(
        file_path: file_path, marker: "auth.engine.events", content: content
      )
      second = described_class.splice_after_marker(
        file_path: file_path, marker: "auth.engine.events", content: content
      )

      expect(first).to have_attributes(ok?: true, lines_added: 60)
      expect(second).to have_attributes(ok?: true, lines_added: 0)
      expect(file_contents.scan(/^line_30$/).size).to eq(1)
    end

    it "splices a contiguous block — partial overlap is treated as not-yet-spliced" do
      # A different snippet sharing one line with `content` shouldn't
      # trip the idempotency check. The check looks for the FULL block.
      write_file(<<~RUBY)
        # seams:insertion-point notifications.notifiable.strategies
        push: "Notifications::Strategies::Push",
      RUBY

      result = described_class.splice_after_marker(
        file_path: file_path,
        marker: "notifications.notifiable.strategies",
        content: "webhook: \"Notifications::Strategies::Webhook\",\n"
      )

      expect(result.ok?).to be(true)
      expect(result.lines_added).to eq(1)
      expect(file_contents).to include("push:")
      expect(file_contents).to include("webhook:")
    end
  end

  describe ".splice_before_marker" do
    it "inserts content on the line immediately before the marker" do
      write_file(<<~RUBY)
        Auth::Engine.routes.draw do
          # seams:insertion-point auth.routes.before_session
          resource :session
        end
      RUBY

      result = described_class.splice_before_marker(
        file_path: file_path,
        marker: "auth.routes.before_session",
        content: "resource :passkey_session\n"
      )

      expect(result.ok?).to be(true)
      expect(result.lines_added).to eq(1)
      # Indent auto-detected from the marker line (2 spaces).
      expect(file_contents).to include("  resource :passkey_session\n  # seams:insertion-point auth.routes.before_session\n")
    end

    it "is idempotent under :before just like :after" do
      write_file(<<~RUBY)
        Auth::Engine.routes.draw do
          # seams:insertion-point auth.routes.before_session
        end
      RUBY

      content = "resource :passkey_session\n"

      described_class.splice_before_marker(
        file_path: file_path, marker: "auth.routes.before_session", content: content
      )
      result = described_class.splice_before_marker(
        file_path: file_path, marker: "auth.routes.before_session", content: content
      )

      expect(result.ok?).to be(true)
      expect(result.lines_added).to eq(0)
      expect(file_contents.scan("resource :passkey_session").size).to eq(1)
    end
  end

  describe ".find_marker" do
    it "returns line number, indent, and marker name when present" do
      write_file(<<~RUBY)
        module Auth
            # seams:insertion-point auth.engine.events
        end
      RUBY

      info = described_class.find_marker(file_path: file_path, marker: "auth.engine.events")

      expect(info).to eq(line_number: 2, indent: "    ", marker: "auth.engine.events")
    end

    it "returns nil when the marker is missing" do
      write_file("module Auth; end\n")
      expect(described_class.find_marker(file_path: file_path, marker: "auth.engine.events")).to be_nil
    end

    it "returns nil when the file does not exist" do
      expect(
        described_class.find_marker(file_path: File.join(tmp_root, "nope.rb"), marker: "x")
      ).to be_nil
    end
  end

  describe ".list_markers" do
    it "returns every marker in the file in source order" do
      write_file(<<~RUBY)
        # seams:insertion-point auth.routes.before_session
        resource :session
        # seams:insertion-point auth.routes.after_oauth
        # seams:insertion-point auth.engine.events
      RUBY

      markers = described_class.list_markers(file_path: file_path).map { |m| m[:marker] }
      expect(markers).to eq(%w[auth.routes.before_session auth.routes.after_oauth auth.engine.events])
    end

    it "returns an empty array for files with no markers" do
      write_file("module Auth; end\n")
      expect(described_class.list_markers(file_path: file_path)).to eq([])
    end

    it "returns an empty array for missing files" do
      expect(described_class.list_markers(file_path: File.join(tmp_root, "nope.rb"))).to eq([])
    end

    it "captures the indent for each marker line independently" do
      write_file(<<~RUBY)
        # seams:insertion-point top.level.no_indent
            # seams:insertion-point nested.deep.four_spaces
      RUBY

      markers = described_class.list_markers(file_path: file_path)
      expect(markers[0][:indent]).to eq("")
      expect(markers[1][:indent]).to eq("    ")
    end
  end
end
