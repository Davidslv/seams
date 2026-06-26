# frozen_string_literal: true

require "seams/permission_registry"

# Access-rule regression spec. Where permissions_spec covers the
# mechanics of `can?` with a single ad-hoc ability, this spec pins the
# WHOLE access matrix the gem ships — the DEFAULT_GRANTS map resolved
# through the role hierarchy and the bypass tiers — so the rules cannot
# silently regress as engines add codes or the defaults move.
#
# Modelled on carer-notes' spec/security/authorization_spec.rb: a
# role -> capability matrix plus the deny tiers. The gem layer is
# account-agnostic (it never sees an account_id); cross-tenant isolation
# is a property of the CALLER passing the per-request membership role, so
# the relevant gem-level guarantee asserted here is that `can?` is a pure
# function of (role, ability) with no shared state that could leak
# between accounts. The request-layer staff? bypass + per-record tenant
# scoping are pinned in the generated app (the accounts engine's
# authorization spec + the admin engine's tenant policies).
# The matrix iterates the real DEFAULT_GRANTS map, so it is a regression
# pin against the constant rather than a hand-maintained copy. Constants
# live at file scope (matching the generator specs) to stay clear of
# Lint/ConstantDefinitionInBlock.
GRANTS = Seams::Permissions::DEFAULT_GRANTS
MEMBER_ABILITIES = GRANTS.fetch("member").freeze
ADMIN_ABILITIES  = GRANTS.fetch("admin").freeze
# A registered-but-ungranted code: lets us prove deny-by-default and the
# system bypass without tripping the UnregisteredAbilityError path.
UNGRANTED_ABILITY = "secret.destroy.core"

RSpec.describe Seams::Permissions do
  # Register every code the shipped defaults reference, exactly as the
  # canonical engines do from their engine.rb, then load the real
  # DEFAULT_GRANTS map.
  before do
    Seams::PermissionRegistry.reset!
    (MEMBER_ABILITIES + ADMIN_ABILITIES).each do |code|
      Seams::PermissionRegistry.register(code, owned_by: "Spec")
    end
    Seams::PermissionRegistry.register(UNGRANTED_ABILITY, owned_by: "Spec")
    Seams.configure { |c| c.permission_grants = GRANTS }
  end

  def can?(role, ability)
    Seams::Permissions.can?(role: role, ability: ability)
  end

  describe "role hierarchy (member < admin < owner)" do
    it "grants every member-level ability to member, and up to admin + owner", :aggregate_failures do
      MEMBER_ABILITIES.each do |ability|
        expect(can?("member", ability)).to be(true), "member should hold #{ability}"
        expect(can?("admin", ability)).to be(true), "admin should inherit #{ability}"
        expect(can?("owner", ability)).to be(true), "owner should inherit #{ability}"
      end
    end

    it "grants every admin-level ability to admin + owner but withholds it from member", :aggregate_failures do
      ADMIN_ABILITIES.each do |ability|
        expect(can?("admin", ability)).to be(true), "admin should hold #{ability}"
        expect(can?("owner", ability)).to be(true), "owner should inherit #{ability}"
        expect(can?("member", ability)).to be(false), "member should NOT hold #{ability}"
      end
    end
  end

  describe "the system bypass" do
    it "lets system resolve a granted ability" do
      expect(can?("system", MEMBER_ABILITIES.first)).to be(true)
    end

    it "lets system resolve a registered-but-ungranted ability (full bypass)" do
      expect(can?("system", UNGRANTED_ABILITY)).to be(true)
    end

    it "does NOT extend the bypass to ordinary roles", :aggregate_failures do
      expect(can?("owner", UNGRANTED_ABILITY)).to be(false)
      expect(can?("admin", UNGRANTED_ABILITY)).to be(false)
      expect(can?("member", UNGRANTED_ABILITY)).to be(false)
    end
  end

  describe "deny-by-default" do
    it "raises for an ability no engine has registered" do
      expect do
        can?("owner", "ghost.read.nowhere")
      end.to raise_error(Seams::Permissions::UnregisteredAbilityError)
    end

    it "denies an unknown role even for a freely-granted ability" do
      # An unrecognised role resolves to just itself (no hierarchy), so
      # it holds nothing — a typo'd or made-up role fails closed.
      expect(can?("superuser", MEMBER_ABILITIES.first)).to be(false)
    end

    it "denies every role when the host clears the grant map", :aggregate_failures do
      Seams.configure { |c| c.permission_grants = {} }

      expect(can?("owner", MEMBER_ABILITIES.first)).to be(false)
      expect(can?("admin", MEMBER_ABILITIES.first)).to be(false)
      expect(can?("member", MEMBER_ABILITIES.first)).to be(false)
    end
  end

  describe "request-layer bypass + cross-tenant isolation intent" do
    it "leaves the staff? bypass to the caller — the gem never special-cases it" do
      # `can?` knows only owner/admin/member/system. There is no `staff`
      # role here: platform staff are bypassed at the REQUEST layer
      # (authorize_permission!), not in the gem. Pin that a staff-shaped
      # role with no grants is denied, so the bypass cannot leak into the
      # gem by accident.
      expect(can?("staff", ADMIN_ABILITIES.first)).to be(false)
    end

    it "is a pure function of (role, ability) — no leakage between checks", :aggregate_failures do
      # Cross-tenant isolation rests on the caller passing the per-request
      # membership role: the same identity can be admin in one account and
      # member in another, and each check must resolve from its own role
      # argument with no shared/global state carried between calls.
      admin_only = ADMIN_ABILITIES.first

      expect(can?("admin", admin_only)).to be(true)
      expect(can?("member", admin_only)).to be(false)
      expect(can?("admin", admin_only)).to be(true)
    end
  end
end
