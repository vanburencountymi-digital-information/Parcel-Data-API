# Read-only grants on the restored parcel schemas (DIC-3161, follow-up to checklist 2.2).
# steward_app gets read-only too for now; write access gets its own review when an
# endpoint needs it. Database-level CONNECT/CREATE were set in 1.4 (DIC-3117).

resource "postgresql_grant" "schema_usage" {
  for_each = { for p in setproduct(var.read_roles, var.schemas) : "${p[0]}|${p[1]}" => { role = p[0], schema = p[1] } }

  database    = var.database
  role        = each.value.role
  schema      = each.value.schema
  object_type = "schema"
  privileges  = ["USAGE"]
}

# Empty `objects` = every table and view in the schema.
resource "postgresql_grant" "select" {
  for_each = { for p in setproduct(var.read_roles, var.schemas) : "${p[0]}|${p[1]}" => { role = p[0], schema = p[1] } }

  database    = var.database
  role        = each.value.role
  schema      = each.value.schema
  object_type = "table"
  privileges  = ["SELECT"]

  depends_on = [postgresql_grant.schema_usage]
}

# The tile functions (and the trigger function).
resource "postgresql_grant" "execute" {
  for_each = { for p in setproduct(var.read_roles, var.schemas) : "${p[0]}|${p[1]}" => { role = p[0], schema = p[1] } }

  database    = var.database
  role        = each.value.role
  schema      = each.value.schema
  object_type = "function"
  privileges  = ["EXECUTE"]

  depends_on = [postgresql_grant.schema_usage]
}

# Tables the owner creates later (for example after the yearly load rebuilds one) follow the same rule.
resource "postgresql_default_privileges" "select" {
  for_each = { for p in setproduct(var.read_roles, var.schemas) : "${p[0]}|${p[1]}" => { role = p[0], schema = p[1] } }

  database    = var.database
  role        = each.value.role
  owner       = var.table_owner
  schema      = each.value.schema
  object_type = "table"
  privileges  = ["SELECT"]
}
