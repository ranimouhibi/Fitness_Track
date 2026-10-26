// Version 2 and 3 of the database: private programs, body measures,
// progress plans (with target weight) and weekly entries.
// Used for new installs (after schema.dart) and for upgrades.
const List<String> schemaV2Statements = [
  // Programs can be private: created by a user for their own progress only.
  'ALTER TABLE programs ADD COLUMN is_private INTEGER NOT NULL DEFAULT 0',

  // Body measures of the profile, one row per body part (in cm).
  '''
  CREATE TABLE IF NOT EXISTS body_measures (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    part TEXT NOT NULL,
    value_cm REAL NOT NULL,
    PRIMARY KEY (user_id, part)
  )
  ''',

  // A progress plan the user follows.
  '''
  CREATE TABLE IF NOT EXISTS progress_plans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    objective TEXT NOT NULL,
    duration_weeks INTEGER NOT NULL,
    start_date TEXT NOT NULL,
    program_id INTEGER REFERENCES programs(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'active'
      CHECK (status IN ('active', 'finished', 'stopped')),
    target_weight REAL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',

  // One row per week of a plan. Week 0 is the starting point.
  '''
  CREATE TABLE IF NOT EXISTS progress_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL REFERENCES progress_plans(id) ON DELETE CASCADE,
    week_no INTEGER NOT NULL,
    entry_date TEXT NOT NULL,
    weight_kg REAL,
    UNIQUE (plan_id, week_no)
  )
  ''',

  // Body measures recorded for each week.
  '''
  CREATE TABLE IF NOT EXISTS progress_entry_measures (
    entry_id INTEGER NOT NULL REFERENCES progress_entries(id) ON DELETE CASCADE,
    part TEXT NOT NULL,
    value_cm REAL NOT NULL,
    PRIMARY KEY (entry_id, part)
  )
  ''',
];