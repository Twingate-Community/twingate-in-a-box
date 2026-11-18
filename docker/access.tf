# Who can reach the box. Terraform creates one group for it and puts the users
# in var.users into it, and every service without its own twingate.groups label
# is granted to that group. Nothing depends on groups that may not exist in a
# given tenant, and nobody outside the list gets in by default.
locals {
  user_emails = distinct([for email in var.users : lower(trimspace(email))])
}

data "twingate_users" "box" {
  email_in = local.user_emails

  lifecycle {
    # Twingate only knows users who have been invited or have signed in, so a
    # typo or a new colleague would otherwise silently get no access.
    postcondition {
      condition     = length(self.users) == length(local.user_emails)
      error_message = "No Twingate user with email: ${join(", ", setsubtract(local.user_emails, [for user in self.users : lower(user.email)]))}. Invite them in the Admin Console first, or fix the address in users."
    }
  }
}

resource "twingate_group" "box" {
  name     = "${local.name_prefix}users"
  user_ids = [for user in data.twingate_users.box.users : user.id]

  # Members come from var.users only. Anyone added in the Admin Console is
  # removed on the next apply, so terraform.tfvars stays the one place to look.
  is_authoritative = true
}
