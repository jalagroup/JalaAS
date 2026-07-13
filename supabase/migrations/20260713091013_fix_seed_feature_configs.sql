-- Fix invalid config values seeded in the previous migration.
-- The option values must match the ConfigOption.value strings in feature_definition.dart.

-- account_statements: "salesman" → "by_salesman"
UPDATE role_features
SET config = jsonb_set(config, '{scope}', '"by_salesman"')
WHERE feature_key = 'account_statements'
  AND config->>'scope' = 'salesman';

-- aging_report: "own" is not a valid salesman_scope; replace with "all"
UPDATE role_features
SET config = jsonb_set(config, '{salesman_scope}', '"all"')
WHERE feature_key = 'aging_report'
  AND config->>'salesman_scope' = 'own';
