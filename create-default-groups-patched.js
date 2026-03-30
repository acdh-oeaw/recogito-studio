const { createClient } = require('@supabase/supabase-js');
const commandLineArgs = require('command-line-args');
const fs = require('fs');

const safeArray = (d) => Array.isArray(d) ? d : [];

const main = async (options) => {

  let supabase = createClient(
    process.env.SUPABASE_HOST,
    process.env.SUPABASE_SERVICE_KEY,
    { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } }
  );

  let config;
  try {
    config = JSON.parse(fs.readFileSync(options.file, 'utf8'));
  } catch (err) {
    console.error(err);
    return;
  }

  //
  // POLICIES
  //
  let policiesInserts = config.policies.map(p => ({
    id: p.id,
    table_name: p.table_name,
    operation: p.operation
  }));

  const policiesResponse = await supabase.from('policies').upsert(policiesInserts).select();
  console.info('Policies:');
  console.table(safeArray(policiesResponse.data));

  //
  // ROLES
  //
  let rolesInsert = [];
  let rolePoliciesInsert = [];

  config.roles.forEach(role => {
    rolesInsert.push({
      id: role.id,
      name: role.name,
      description: role.description
    });

    role.policies.forEach(pol => {
      rolePoliciesInsert.push({ role_id: role.id, policy_id: pol });
    });
  });

  const rolesResponse = await supabase.from('roles').upsert(rolesInsert).select();
  const rolePolicesResponse = await supabase
    .from('role_policies')
    .upsert(rolePoliciesInsert, { onConflict: 'role_id,policy_id' })
    .select();

  console.info('Roles:');
  console.table(safeArray(rolesResponse.data));
  console.info('Role Policies:');
  console.table(safeArray(rolePolicesResponse.data));

  //
  // ORGANIZATION GROUPS
  //
  let organizationGroupInserts = config.org_groups.map(g => ({
    id: g.id,
    role_id: g.role_id,
    name: g.name,
    description: g.description,
    is_admin: g.is_admin,
    is_default: g.is_default,
    is_read_only: g.is_read_only
  }));

  const orgGroupsResponse = await supabase
    .from('organization_groups')
    .upsert(organizationGroupInserts, { onConflict: 'role_id' });

  const orgAdminGroup = organizationGroupInserts.find(g => g.is_admin);
  console.log("Org group:", orgAdminGroup);

  const getOrgAdminResponse = await supabase
    .from('organization_groups')
    .select()
    .eq('id', orgAdminGroup.id);

  const adminGroupData = safeArray(getOrgAdminResponse.data);

  console.info("Organization Admin Group:");
  console.table(adminGroupData);

  //
  // RETRIEVE ADMIN PROFILE
  //
  let orgAdminProfile = await supabase
    .from('profiles')
    .select()
    .eq('email', config.admin.admin_email);

  let adminData = safeArray(orgAdminProfile.data);

  if (adminData.length === 0) {

    const createAdminUserResponse = await supabase.auth.admin.createUser({
      email: config.admin.admin_email,
      password: process.env.ORG_ADMIN_PW,
      email_confirm: true
    });

    if (createAdminUserResponse.error) {
      console.error("Error creating org admin:", createAdminUserResponse.error);
    }

    orgAdminProfile = await supabase
      .from('profiles')
      .select()
      .eq('email', config.admin.admin_email);

    adminData = safeArray(orgAdminProfile.data);
  }

  console.info("Organization Admin:");
  console.info(adminData[0] || null);

  const adminId = adminData.length ? adminData[0].id : null;
  const adminGroupId = adminGroupData.length ? adminGroupData[0].id : null;

  //
  // ADD ADMIN TO GROUP
  //
  for (let i = 0; i < config.admin.admin_groups.length; i++) {
    await supabase
      .from('group_users')
      .update({ group_type: 'organization', type_id: adminGroupId })
      .eq('user_id', adminId);
  }

  //
  // DEFAULT PROJECT + LAYER GROUPS
  //
  let defaultGroups = [];

  config.project_groups.forEach(g => {
    defaultGroups.push({
      id: g.id,
      group_type: "project",
      name: g.name,
      description: g.description,
      role_id: g.role_id,
      is_admin: !!g.is_admin,
      is_default: !!g.is_default,
      is_read_only: !!g.is_read_only
    });
  });

  config.layer_groups.forEach(g => {
    defaultGroups.push({
      id: g.id,
      group_type: "layer",
      name: g.name,
      description: g.description,
      role_id: g.role_id,
      is_admin: !!g.is_admin,
      is_default: !!g.is_default,
      is_read_only: !!g.is_read_only
    });
  });

  await supabase.from('default_groups').upsert(defaultGroups);
};

const optionDefinitions = [
  { name: 'file', alias: 'f', type: String }
];

main(commandLineArgs(optionDefinitions));