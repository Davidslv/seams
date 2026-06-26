# frozen_string_literal: true

module Seams
  # Permissions module — public API for authorisation across engines.
  #
  # Engines register the ability codes they understand at boot through
  # Seams::PermissionRegistry, mirroring the event bus. Authorisation is
  # resolved through Seams::Permissions.can?, which answers from a
  # code-defined role hierarchy and a host-configurable grant map. Nothing
  # here enforces permissions on a request; it is the machinery that the
  # request and controller layers build on in later phases.
  module Permissions
    class Error < Seams::Error; end

    # Raised when a permission is checked for an ability that no engine has
    # registered.
    class UnregisteredAbilityError < Error; end

    # Raised when two engines try to register the same ability code.
    class DuplicateAbilityError < Error; end

    # Raised when an ability code doesn't follow the resource.action.engine
    # convention (e.g., "invoice.read.billing").
    class InvalidAbilityNameError < Error; end

    # Three dot-separated segments, lowercase, snake_case allowed. Matches
    # the event name convention so abilities and events read alike.
    NAME_PATTERN = /\A[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\z/

    # Roles ordered from most to least privileged. Each role inherits every
    # ability granted to the roles below it (owner ⊇ admin ⊇ member).
    ROLE_HIERARCHY = %w[owner admin member].freeze

    # A pseudo-role that bypasses every check — used by trusted internal
    # callers such as background jobs and system actors.
    SYSTEM_ROLE = "system"

    # Sensible default grant map so `can?` allows things out of the box,
    # keyed by role. `member` may read; `admin` may manage. `owner`
    # inherits everything granted to `admin` (and through it `member`)
    # via ROLE_HIERARCHY, and `system` bypasses checks entirely — so
    # neither needs its own entry here. Hosts override the whole map
    # through `Seams.configuration.permission_grants`. The codes mirror
    # what each canonical engine registers from its engine.rb.
    DEFAULT_GRANTS = {
      "member" => %w[
        identity.read.auth
        invoice.read.billing
        subscription.read.billing
        team.read.teams
        account.read.accounts
        membership.read.accounts
        notification.read.notifications
      ].freeze,
      "admin" => %w[
        identity.manage.auth
        invoice.manage.billing
        subscription.manage.billing
        plan.manage.billing
        lifetime.manage.billing
        team.manage.teams
        member.manage.teams
        invitation.manage.teams
        account.manage.accounts
        membership.manage.accounts
        notification.manage.notifications
        preference.manage.notifications
      ].freeze
    }.freeze

    def self.valid_name?(name)
      NAME_PATTERN.match?(name.to_s)
    end

    def self.assert_valid_name!(name)
      return if valid_name?(name)

      raise InvalidAbilityNameError,
            "Ability name #{name.inspect} must follow resource.action.engine " \
            "(e.g. invoice.read.billing)"
    end

    # Resolves whether a role is allowed an ability. The role string is one
    # of owner/admin/member/system; request-layer bypasses (e.g. staff?)
    # are handled by callers, not here. Raises if the ability was never
    # registered, matching the event bus's loud-failure behaviour.
    def self.can?(role:, ability:)
      ability = ability.to_s

      unless PermissionRegistry.registered?(ability)
        raise UnregisteredAbilityError,
              "Ability #{ability.inspect} is not registered; register it with " \
              "Seams::PermissionRegistry.register before checking it"
      end

      role = role.to_s
      return true if role == SYSTEM_ROLE

      roles_for(role).any? { |r| granted_abilities_for(r).include?(ability) }
    end

    # The role itself plus every role it inherits from, lowest first. An
    # unknown role resolves to just itself (and therefore no grants).
    def self.roles_for(role)
      role  = role.to_s
      index = ROLE_HIERARCHY.index(role)
      return [role] unless index

      ROLE_HIERARCHY[index..]
    end

    # Abilities granted directly to a single role in the configured map,
    # tolerating string or symbol keys and values.
    def self.granted_abilities_for(role)
      grants = Seams.configuration.permission_grants
      list   = grants[role.to_s] || grants[role.to_sym]
      Array(list).map(&:to_s)
    end
  end
end
