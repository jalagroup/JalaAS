-- Assign مدير عام role to the system admin account.
-- Also assign it to any existing user with salesman='0' or user_type='admin'
-- so old super-admins keep full access after the role migration.
UPDATE users
SET role_id = '00000000-0000-0001-0000-000000000001'
WHERE role_id IS NULL
  AND (salesman = '0' OR user_type = 'admin');
