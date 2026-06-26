# frozen_string_literal: true

require "seams/permission_registry"
require "seams/permissions"

# Behavioural coverage for the generated admin Pundit policies (Phase 3).
# The policy templates are pure Ruby (no ERB tags), so we load them into
# the gem test process and exercise the real source the generator emits
# rather than a copy. The point is to lock the access matrix in place
# while proving every tenant decision now routes through the gem's
# permission registry instead of a `role == "admin"` literal.

POLICY_TEMPLATE_ROOT = File.expand_path(
  "../../../lib/generators/seams/admin/templates/app/policies/admin",
  __dir__
)

def load_admin_policy_template(relative_path)
  path = File.join(POLICY_TEMPLATE_ROOT, relative_path)
  # rubocop:disable Security/Eval
  eval(File.read(path), TOPLEVEL_BINDING, path)
  # rubocop:enable Security/Eval
end

# Base classes first (concrete policies inherit from them), then the
# concrete policies under test.
load_admin_policy_template("tenant/application_policy.rb.tt")
load_admin_policy_template("tenant/invoice_policy.rb.tt")
load_admin_policy_template("tenant/notification_policy.rb.tt")
load_admin_policy_template("platform/application_policy.rb.tt")
load_admin_policy_template("platform/invoice_policy.rb.tt")

RSpec.describe Admin::Tenant::ApplicationPolicy do
  # Stand-in for Seams::Admin::Context — the pundit_user the controller
  # passes in. Both fields are nil-safe, exactly like the real Struct.
  let(:context_struct) { Struct.new(:identity, :membership) }
  let(:staff_identity)     { double(staff?: true) }
  let(:non_staff_identity) { double(staff?: false) }

  def membership(role:, account_id: 1)
    double(role: role, account_id: account_id)
  end

  before do
    Seams::PermissionRegistry.reset!
    Seams::PermissionRegistry.register("invoice.manage.billing", owned_by: "Billing")
    Seams::PermissionRegistry.register("notification.manage.notifications", owned_by: "Notifications")
    # Mirror the shipped DEFAULT_GRANTS: manage codes sit in the admin
    # tier (and owner inherits via ROLE_HIERARCHY); member holds neither.
    Seams.configure { |c| c.permission_grants = Seams::Permissions::DEFAULT_GRANTS }
  end

  after { Seams.reset_configuration! }

  describe "decision routes through Seams::Permissions.can?" do
    it "asks the registry with the membership role and the resource ability" do
      user   = context_struct.new(non_staff_identity, membership(role: "admin"))
      policy = Admin::Tenant::InvoicePolicy.new(user, double(account_id: 1))

      allow(Seams::Permissions).to receive(:can?).and_call_original
      policy.index?

      expect(Seams::Permissions)
        .to have_received(:can?)
        .with(role: "admin", ability: "invoice.manage.billing")
    end
  end

  describe "Admin::Tenant access matrix (behaviour unchanged)" do
    it "admin role is permitted (admin tier holds the manage ability)" do
      user = context_struct.new(non_staff_identity, membership(role: "admin"))

      expect(Admin::Tenant::InvoicePolicy.new(user, nil).index?).to be(true)
    end

    it "owner role is permitted (inherits the admin grant via ROLE_HIERARCHY)" do
      user = context_struct.new(non_staff_identity, membership(role: "owner"))

      expect(Admin::Tenant::InvoicePolicy.new(user, nil).index?).to be(true)
    end

    it "member role is denied (member tier lacks the manage ability)" do
      user = context_struct.new(non_staff_identity, membership(role: "member"))

      expect(Admin::Tenant::InvoicePolicy.new(user, nil).index?).to be(false)
    end

    it "a request with no resolved membership is denied (fail closed)" do
      user = context_struct.new(non_staff_identity, nil)

      expect(Admin::Tenant::InvoicePolicy.new(user, nil).index?).to be(false)
    end

    it "platform staff bypass the role check entirely" do
      user = context_struct.new(staff_identity, nil)

      expect(Admin::Tenant::InvoicePolicy.new(user, nil).index?).to be(true)
    end

    it "the system pseudo-role bypasses inside can? (trusted internal actor)" do
      user = context_struct.new(non_staff_identity, membership(role: "system"))

      expect(Admin::Tenant::InvoicePolicy.new(user, nil).index?).to be(true)
    end

    it "per-record predicates combine the role gate with the tenant scope" do
      user      = context_struct.new(non_staff_identity, membership(role: "admin", account_id: 7))
      own_row   = double(account_id: 7)
      other_row = double(account_id: 99)

      expect(Admin::Tenant::InvoicePolicy.new(user, own_row).destroy?).to be(true)
      expect(Admin::Tenant::InvoicePolicy.new(user, other_row).destroy?).to be(false)
    end
  end

  describe "Admin::Tenant::NotificationPolicy (manage code keeps member denied)" do
    it "admin is permitted, member denied — matches pre-refactor behaviour" do
      admin_user  = context_struct.new(non_staff_identity, membership(role: "admin"))
      member_user = context_struct.new(non_staff_identity, membership(role: "member"))

      expect(Admin::Tenant::NotificationPolicy.new(admin_user, nil).index?).to be(true)
      expect(Admin::Tenant::NotificationPolicy.new(member_user, nil).index?).to be(false)
    end
  end

  describe "Admin::Platform access matrix (staff bypass tier, unchanged)" do
    it "any staff Identity sees everything" do
      user = context_struct.new(staff_identity, nil)

      expect(Admin::Platform::InvoicePolicy.new(user, nil).index?).to be(true)
      expect(Admin::Platform::InvoicePolicy.new(user, nil).destroy?).to be(true)
    end

    it "a non-staff Identity is denied regardless of membership role" do
      user = context_struct.new(non_staff_identity, membership(role: "owner"))

      expect(Admin::Platform::InvoicePolicy.new(user, nil).index?).to be(false)
    end
  end
end
