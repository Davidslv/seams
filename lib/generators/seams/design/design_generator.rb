# frozen_string_literal: true

require "fileutils"
require "rails/generators"
require "seams"
require "generators/seams/engine/engine_generator"
require "seams/generators/host_injector"
require "seams/generators/eject_aware"

module Seams
  module Generators
    # Generates the canonical Design engine on top of the generic engine
    # scaffold — Phase 1 (this unit): the engine skeleton, the non-isolated
    # wiring that makes `ui_*` helpers + `ui/` partials visible host-wide, the
    # Tailwind v4 token injection, the FormBuilder default, and the icon sprite
    # render.
    #
    # The design engine is DELIBERATELY NOT `isolate_namespace`d (D4 in
    # proposals/design_system_engine.md). The whole value is that a component
    # renders anywhere in the host and in every other engine's views without
    # ceremony, which requires the partials and the helper to live in the host's
    # view paths and `ActionController::Base`. The base EngineGenerator produces
    # an isolated engine, so this generator overwrites lib/design/engine.rb with
    # the non-isolated form and removes the single-namespace leftovers the base
    # scaffold ships.
    #
    # Naming (D1): the engine, CLI verb, folder and Ruby namespace are `design`
    # (`Design::`); the VIEW + HELPER surface is `ui` — partials at
    # app/views/ui/_<name>.html.erb, previews at app/views/ui/previews/, and
    # auto-derived helpers named `ui_<name>`.
    #
    # Later sub-issues import this skeleton: #17 (tokens/theme), #18 (helpers +
    # gallery + tests), #19 (FormBuilder + form components), #20 (the
    # design:component generator), and the Phase 2/3 component + shell units.
    #
    # Run with: bin/seams design   (or bin/rails generate seams:design)
    #
    # Like the admin generator, this is a long-but-flat orchestration class: each
    # public method is one small, single-purpose generate step, so the length is
    # inherent to the number of files the engine ships, not tangled logic.
    # rubocop:disable Metrics/ClassLength
    class DesignGenerator < Rails::Generators::Base
      include Seams::Generators::HostInjector
      include Seams::Generators::EjectAware

      source_root File.expand_path("templates", __dir__)

      ENGINE_NAME = "design"

      def create_base_engine
        # The base EngineGenerator raises if engines/design/ already exists.
        # Skip it on a re-run so a second `bin/seams design` is a no-op on the
        # engine and simply re-applies the (idempotent) host wiring below.
        if File.directory?(engine_path(""))
          say "  exist   engines/design (kept — re-applying host wiring only)", :blue
          return
        end

        EngineGenerator.start([ENGINE_NAME], destination_root: destination_root)
      end

      # The base EngineGenerator emits an ISOLATED engine. The design engine is
      # non-isolated by design (D4), so overwrite lib/design/engine.rb with the
      # non-isolated form that auto-wires the helper into ActionController::Base.
      # engine.rb stays framework-managed (NOT eject-aware), like every other
      # canonical generator's engine.rb.
      def overwrite_engine_entry_point
        template "lib/engine.rb.tt", engine_path("lib/design/engine.rb"), force: true
        template "lib/design.rb.tt", engine_path("lib/design.rb"),        force: true
      end

      # The base scaffold ships an isolated engine's ApplicationController and
      # ApplicationRecord under app/controllers/design/ and app/models/design/.
      # A view-layer engine needs neither — its only controller is the dev-only
      # guide (created below) and it has no models — so remove the leftovers.
      def remove_isolated_leftovers
        # config/routes.rb is KEPT (an empty `Design::Engine.routes.draw do end`)
        # so the engine stays mountable in the dummy app + host; the dev-only
        # guide route (#18) is drawn into it later.
        %w[
          app/controllers/design/application_controller.rb
          app/models/design/application_record.rb
          spec/design_spec.rb
        ].each do |relative|
          full = engine_path(relative)
          next unless File.exist?(full)

          FileUtils.rm(full)
          say "  remove  #{relative} (isolated-engine leftover)", :red
        end

        %w[app/controllers/design app/models/design].each do |relative|
          full = engine_path(relative)
          Dir.rmdir(full) if File.directory?(full) && Dir.empty?(full)
        end
      end

      # The auto-wire registry: Design.component_names derives the public
      # component list from the preview partials, and resets on reload so a new
      # component appears without a server restart. Ported from quire-saas's
      # lib/compositor.rb (compositor -> design, compositor/previews -> ui/previews).
      def create_auto_wire
        template "lib/design/components.rb.tt", engine_path("lib/design/components.rb")
      end

      # The host-wide helper module. ui_icon is the one hand-written helper;
      # define_component_helpers! auto-derives ui_<name> for every preview.
      # Ported from quire-saas's app/helpers/compositor_helper.rb.
      def create_helper
        template "app/helpers/design/ui_helper.rb.tt",
                 engine_path("app/helpers/design/ui_helper.rb")
      end

      # The default form builder. Subclasses the standard Rails builder and only
      # ADDS ui_* methods, so it is safe as the app-wide default. Ported from
      # quire-saas's app/form_builders/compositor/form_builder.rb (compositor_*
      # -> ui_*, the field partial path compositor/field -> ui/field). #19
      # fleshes out the textarea/select/submit helpers + the ui/field partial.
      def create_form_builder
        template "app/form_builders/design/form_builder.rb.tt",
                 engine_path("app/form_builders/design/form_builder.rb")
      end

      # The form-input component set (#19): the building blocks Design::FormBuilder
      # and hand-written forms render. Ported faithfully from quire-saas's
      # compositor (compositor_* -> ui_*, quire copy neutralised in the previews):
      #
      #   - field        the label/input/hint/error wrapper with baked-in
      #                  aria-invalid + aria-describedby wiring (what
      #                  f.ui_text_field renders);
      #   - checkbox     an accessible labelled checkbox with an optional hint;
      #   - radio        a labelled radio (grouped by name in a fieldset);
      #   - switch       a role="switch" toggle;
      #   - input_group  a text input with an optional prefix/suffix affix.
      #
      # Each ships with a companion preview, which is what makes it "public": the
      # auto-wire derives ui_<name> from the preview and the gallery lists it.
      # Eject-aware so a host can own a component without losing it on regenerate.
      def create_form_components
        %w[field checkbox radio switch input_group].each do |name|
          template_unless_ejected "app/views/ui/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/_#{name}.html.erb")
          template_unless_ejected "app/views/ui/previews/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/previews/_#{name}.html.erb")
        end
      end

      # The icon sprite + icon partials — the minimum view surface the skeleton
      # needs so `render "ui/icon_sprite"` (wired into the host layout below) and
      # ui_icon resolve. #25 ships the full primitive + icon set; these two are
      # the load-bearing pair the host layout references on first boot.
      def create_icon_partials
        template_unless_ejected "app/views/ui/_icon.html.erb.tt",
                                engine_path("app/views/ui/_icon.html.erb")
        template_unless_ejected "app/views/ui/_icon_sprite.html.erb.tt",
                                engine_path("app/views/ui/_icon_sprite.html.erb")
      end

      # The seed component set — enough for the gallery + the contract/render
      # tests to have something real to render. Ported faithfully from
      # quire-saas's compositor (compositor_* -> ui_*, quire copy neutralised):
      # _button (takes a content block + variant/size) and _tag (a required
      # `label:` strict local — the contract test relies on it being required).
      # Each ships with a companion preview, which is what makes it "public":
      # the auto-wire derives ui_<name> from the preview, and the gallery lists
      # it. Eject-aware so a host can own a component without losing it on
      # regenerate. #21+ ship the full component set.
      def create_seed_components
        %w[button tag].each do |name|
          template_unless_ejected "app/views/ui/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/_#{name}.html.erb")
          template_unless_ejected "app/views/ui/previews/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/previews/_#{name}.html.erb")
        end
      end

      # The Navigation component set (Phase 2, GROUPKEY = nav). Ported faithfully
      # from quire-saas's compositor (compositor_* -> ui_*, quire copy
      # neutralised in the previews), each carrying its baked-in navigation
      # accessibility roles/aria:
      #
      #   - breadcrumb   a nav[aria-label=Breadcrumb] trail with aria-current=page;
      #   - pagination   a nav[aria-label=Pagination] with per-page aria-current;
      #   - menu         a role=menu list of role=menuitem links/buttons;
      #   - segmented    a role=group of aria-pressed toggle buttons;
      #   - stepper      an ordered list with aria-current=step + done ticks;
      #   - toolbar      a role=toolbar of labelled icon/text buttons;
      #   - outline      a nav[aria-label=Outline] heading tree with aria-current.
      #
      # Each ships with a companion preview, which is what makes it "public": the
      # auto-wire derives ui_<name> from the preview and the gallery lists it.
      # Eject-aware so a host can own a component without losing it on regenerate.
      def create_nav_components
        %w[breadcrumb pagination menu segmented stepper toolbar outline].each do |name|
          template_unless_ejected "app/views/ui/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/_#{name}.html.erb")
          template_unless_ejected "app/views/ui/previews/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/previews/_#{name}.html.erb")
        end
      end

      # The Overlays component set (Phase 2, GROUPKEY = overlays). Ported
      # faithfully from quire-saas's compositor (compositor_* -> ui_*,
      # compositor-dialog controller -> ui-dialog, quire copy neutralised in the
      # previews), each carrying its baked-in overlay accessibility:
      #
      #   - dialog     a native <dialog aria-labelledby> with a labelled close
      #                button, driven by a ui-dialog Stimulus controller the host
      #                supplies (data-controller / data-action wiring baked in);
      #   - drawer     an <aside aria-label> side-panel landmark;
      #   - popover    a role=note annotation bubble;
      #   - savestate  a role=status live region (saved / saving / unsaved).
      #
      # Each ships with a companion preview, which is what makes it "public": the
      # auto-wire derives ui_<name> from the preview and the gallery lists it.
      # Eject-aware so a host can own a component without losing it on regenerate.
      def create_overlays_components
        %w[dialog drawer popover savestate].each do |name|
          template_unless_ejected "app/views/ui/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/_#{name}.html.erb")
          template_unless_ejected "app/views/ui/previews/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/previews/_#{name}.html.erb")
        end
      end

      # The Primitives & icons component set (Phase 2, GROUPKEY = primitives).
      # The icon + icon_sprite primitives ship from create_icon_partials above;
      # this set adds the remaining low-level building blocks, ported faithfully
      # from quire-saas's compositor (compositor_* -> ui_*, quire copy
      # neutralised in the previews), each carrying its baked-in accessibility:
      #
      #   - panel   a plain raised content surface (a content-block wrapper);
      #   - diff    a per-line add/del/ctx list whose +/- signs are aria-labelled
      #             "added"/"removed" so the glyph alone is not load-bearing;
      #   - empty   an empty-state with a required title + content-block body.
      #
      # Each ships with a companion preview, which is what makes it "public": the
      # auto-wire derives ui_<name> from the preview and the gallery lists it.
      # Eject-aware so a host can own a component without losing it on regenerate.
      def create_primitive_components
        %w[panel diff empty].each do |name|
          template_unless_ejected "app/views/ui/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/_#{name}.html.erb")
          template_unless_ejected "app/views/ui/previews/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/previews/_#{name}.html.erb")
        end
      end

      # The Actions & status component set (Phase 2, GROUPKEY = actions). Ported
      # faithfully from quire-saas's compositor (compositor_* -> ui_*, quire copy
      # neutralised in the previews), each carrying its baked-in accessibility:
      #
      #   - banner   a page-level role=region announcement with a tone variant;
      #   - toast    a role=status transient notification;
      #   - note     an inline annotation span.
      #
      # Each ships with a companion preview, which is what makes it "public": the
      # auto-wire derives ui_<name> from the preview and the gallery lists it.
      # Eject-aware so a host can own a component without losing it on regenerate.
      def create_actions_components
        %w[banner toast note].each do |name|
          template_unless_ejected "app/views/ui/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/_#{name}.html.erb")
          template_unless_ejected "app/views/ui/previews/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/previews/_#{name}.html.erb")
        end
      end

      # The Data display component set (Phase 2, GROUPKEY = data). Ported
      # faithfully from quire-saas's compositor (compositor_* -> ui_*, quire copy
      # neutralised in the previews), each carrying its baked-in accessibility:
      #
      #   - card         a titled content surface;
      #   - data_table   a <table> with a caption + scoped headers;
      #   - chapter_row  a manuscript chapter list row;
      #   - build_row    an export/build status list row;
      #   - counter      a labelled numeric stat;
      #   - meter        a <meter>-backed progress indicator;
      #   - kbd          a <kbd> keyboard-shortcut glyph.
      #
      # Each ships with a companion preview, which is what makes it "public": the
      # auto-wire derives ui_<name> from the preview and the gallery lists it.
      # Eject-aware so a host can own a component without losing it on regenerate.
      def create_data_components
        %w[card data_table chapter_row build_row counter meter kbd].each do |name|
          template_unless_ejected "app/views/ui/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/_#{name}.html.erb")
          template_unless_ejected "app/views/ui/previews/_#{name}.html.erb.tt",
                                  engine_path("app/views/ui/previews/_#{name}.html.erb")
        end
      end

      # The living gallery (dev/test only). The controller renders every
      # component from its preview so the docs cannot drift; the route is guarded
      # to Rails.env.local? both in the controller (404 in production) and at the
      # host routes (drawn inside an `if Rails.env.local?` block). Ported from
      # quire-saas's compositor guide. Eject-aware so a host can restyle the
      # gallery chrome.
      def create_guide
        template "app/controllers/design/guide_controller.rb.tt",
                 engine_path("app/controllers/design/guide_controller.rb")
        template_unless_ejected "app/views/layouts/design/guide.html.erb.tt",
                                engine_path("app/views/layouts/design/guide.html.erb")
        template_unless_ejected "app/views/design/guide/index.html.erb.tt",
                                engine_path("app/views/design/guide/index.html.erb")
      end

      # The design:component generator (#20): ships INSIDE the generated engine
      # at engines/design/lib/generators/design/component/, so a host can run
      # `rails g design:component <name>` (Rails auto-discovers it on the engine's
      # lib path; no registration needed). Ported from quire-saas's Compositor.
      #
      # copy_file (NOT template): the generator's own .tt templates are ERB run by
      # `rails g design:component`, so they must reach the engine VERBATIM. The
      # meta-generator's ERB would un-escape their `<%%` markers and nest the
      # `<%= file_name %>` placeholders inside a real tag — a parse error.
      def create_component_generator
        copy_file "lib/generators/design/component/component_generator.rb.tt",
                  engine_path("lib/generators/design/component/component_generator.rb")
        copy_file "lib/generators/design/component/templates/component.html.erb.tt",
                  engine_path("lib/generators/design/component/templates/component.html.erb.tt")
        copy_file "lib/generators/design/component/templates/preview.html.erb.tt",
                  engine_path("lib/generators/design/component/templates/preview.html.erb.tt")
      end

      def create_runtime_spec
        template "spec/runtime/design_boot_spec.rb.tt",
                 engine_path("spec/runtime/design_boot_spec.rb")
        template "spec/runtime/ui_components_spec.rb.tt",
                 engine_path("spec/runtime/ui_components_spec.rb")
        template "spec/runtime/form_builder_spec.rb.tt",
                 engine_path("spec/runtime/form_builder_spec.rb")
        template "spec/runtime/guide_spec.rb.tt",
                 engine_path("spec/runtime/guide_spec.rb")
      end

      def overwrite_readme
        template "README.md.tt", engine_path("README.md"), force: true
      end

      # --- Host wiring ----------------------------------------------------------

      def wire_into_host
        # Tailwind v4 is a hard dependency (D2): the @theme token layer the
        # engine ships is Tailwind-native. Inject the gem and write the token
        # block into the host's application.css.
        host_inject_gem("tailwindcss-rails", "~> 4.0")
        inject_theme_into_host_css
        set_host_default_form_builder
        render_sprite_in_host_layout
        draw_guide_route_in_host
      end

      def report_summary
        say report_summary_text, :green
      end

      private

      # Draw the dev/test-only living-gallery route into the HOST's routes. The
      # design engine is non-isolated, so its Design::GuideController lives on the
      # host's controller path and a plain host route reaches it — matching how
      # quire-saas exposes /compositor/guide. The route is wrapped in an
      # `if Rails.env.local?` guard so it does not exist in production at all
      # (defence in depth with the controller's own guard_available? 404).
      # Idempotent: skips if the route is already drawn.
      def draw_guide_route_in_host
        routes = host_path("config/routes.rb")
        unless File.exist?(routes)
          return host_skip("config/routes.rb not found — add the guide route " \
                           '(get "design/guide" => "design/guide#index") yourself')
        end

        return if File.read(routes).include?('"design/guide#index"')

        say "  inject  config/routes.rb (design/guide — dev/test only)", :green
        inject_into_file routes, after: routes_draw_anchor do
          <<-RUBY
  # The seams design living gallery — dev/test only. Renders every ui_*
  # component from its preview so the docs cannot drift. Guarded here AND in
  # the controller so it never reaches production.
  if Rails.env.local?
    get "design/guide" => "design/guide#index", as: :design_guide
  end
          RUBY
        end
      end

      def engine_path(relative)
        File.join(destination_root, "engines", ENGINE_NAME, relative)
      end

      # Write the neutral @theme token layer into the host's Tailwind entrypoint.
      # This is the SINGLE SOURCE every ui_* component reads (#17): the full,
      # WCAG-AA-audited neutral default — the @theme palette/type tokens, the
      # `:root` alias layer (type scale, spacing, radius, shadow, motion, layout,
      # z-index, breakpoints) and the base focus/selection/skip-link rules. The
      # block lives in templates/app/assets/tailwind/_tokens.css so it stays
      # readable and diffable; the generator appends it verbatim.
      #
      # Also adds an `@source` line so Tailwind scans the engine's component
      # partials and builds the utility classes they emit. If the host has no
      # application.css yet (no tailwindcss-rails installed at generate time),
      # create one with the `@import "tailwindcss"` line so the first boot has a
      # working stylesheet. Idempotent — skips if the token marker is present.
      def inject_theme_into_host_css
        css_path = host_path("app/assets/tailwind/application.css")

        unless File.exist?(css_path)
          FileUtils.mkdir_p(File.dirname(css_path))
          create_file css_path, host_css_preamble
        end

        # Ensure Tailwind scans the engine's ui/ partials even when the host
        # already had its own application.css (e.g. after tailwindcss:install).
        unless File.read(css_path).include?(ENGINE_SOURCE_GLOB)
          append_to_file css_path, <<~CSS

            /* Scan the seams design engine so the classes its ui/ partials emit are built. */
            @source "#{ENGINE_SOURCE_GLOB}";
          CSS
        end

        return if File.read(css_path).include?(THEME_MARKER)

        say "  inject  app/assets/tailwind/application.css (@theme tokens)", :green
        append_to_file css_path, "\n#{neutral_theme_block}"
      end

      ENGINE_SOURCE_GLOB = "../../../engines/design/app/views"
      private_constant :ENGINE_SOURCE_GLOB

      THEME_MARKER = "seams:design tokens"
      private_constant :THEME_MARKER

      # The Tailwind entrypoint we create when the host has none yet: the import
      # plus an @source line so Tailwind scans the engine's ui/ partials and
      # builds the utility classes they emit.
      def host_css_preamble
        <<~CSS
          @import "tailwindcss";

          /* Scan the seams design engine so the classes its ui/ partials emit are built. */
          @source "#{ENGINE_SOURCE_GLOB}";
        CSS
      end

      # The full neutral default token layer (#17), read verbatim from the
      # template so the large CSS stays readable and reviewable in one place.
      def neutral_theme_block
        File.read(File.expand_path("templates/app/assets/tailwind/_tokens.css", __dir__))
      end

      # Make Design::FormBuilder the host's default form builder so every
      # `form_with` / `form_for` gets the f.ui_* field methods without passing
      # `builder:`. Injected into config/application.rb inside the Application
      # class body. Idempotent.
      def set_host_default_form_builder
        application_rb = host_path("config/application.rb")
        unless File.exist?(application_rb)
          return host_skip("config/application.rb not found — set " \
                           "config.action_view.default_form_builder = \"Design::FormBuilder\" yourself")
        end

        contents = File.read(application_rb)
        return if contents.include?("default_form_builder")

        say "  inject  config/application.rb (default_form_builder = Design::FormBuilder)", :green
        inject_into_class application_rb, "Application", <<~RUBY
          # The Design engine's FormBuilder only ADDS ui_* field helpers; the
          # standard f.text_field / f.select / f.submit are untouched, so it is
          # safe as the app-wide default. Set as a string so the constant is
          # resolved lazily, after the engine has loaded.
          config.action_view.default_form_builder = "Design::FormBuilder"
        RUBY
      end

      # Render the icon sprite once near the top of <body> in the host layout so
      # the ui_* components can reference icons by fragment without an external
      # request. Injected immediately after the opening <body> tag. Skips if the
      # host layout is missing or already renders the sprite.
      def render_sprite_in_host_layout
        layout = host_path("app/views/layouts/application.html.erb")
        unless File.exist?(layout)
          return host_skip("app/views/layouts/application.html.erb not found — " \
                           'add `<%= render "ui/icon_sprite" %>` near the top of <body> yourself')
        end

        contents = File.read(layout)
        return if contents.include?('render "ui/icon_sprite"')

        body_anchor = /<body[^>]*>\n/
        unless contents.match?(body_anchor)
          return host_skip("app/views/layouts/application.html.erb has no <body> tag — " \
                           'add `<%= render "ui/icon_sprite" %>` near the top of <body> yourself')
        end

        say "  inject  app/views/layouts/application.html.erb (render \"ui/icon_sprite\")", :green
        inject_into_file layout, after: body_anchor do
          %(    <%# seams design — icon sprite for ui_* components %>\n) +
            %(    <%= render "ui/icon_sprite" %>\n)
        end
      end

      def report_summary_text
        <<~TXT

          Design engine generated at engines/design/

          Next steps:
            1. bundle install
               (picks up tailwindcss-rails, injected into the host Gemfile)

            2. bin/rails tailwindcss:install   (if Tailwind isn't set up yet)
               then build it:  bin/rails tailwindcss:build

            3. Use the components anywhere in the host or another engine's views:
                 <%= ui_button(variant: :primary) { "Save" } %>
                 <%= form_with model: @record do |f| %>
                   <%= f.ui_text_field :title, label: "Title" %>
                 <% end %>

          The engine is non-isolated: ui_* helpers and ui/ partials resolve
          everywhere, and Design::FormBuilder is the host default form builder.

          Retheme by overriding the @theme tokens in
          app/assets/tailwind/application.css.

          Run the engine specs:
            bin/rails seams:test[design]

        TXT
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
