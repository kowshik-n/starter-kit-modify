-- Run all migrations in order
\i 01_drop_existing.sql
\i 02_create_functions.sql
\i 03_create_tables.sql
\i 04_create_indexes.sql
\i 05_enable_rls.sql
\i 06_create_policies.sql
\i 07_create_triggers.sql
\i 08_create_user_handler.sql
\i 09_grant_permissions.sql
\i 10_insert_plans.sql 