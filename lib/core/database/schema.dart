// All table definitions. Add new tables here and bump the version in database_helper.dart.
const List<String> schemaStatements = [
  // ---------- Users and coaches ----------
  '''
  CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    role TEXT NOT NULL CHECK (role IN ('user', 'coach', 'admin')),
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT,
    password_hash TEXT NOT NULL,
    birth_date TEXT,
    height_cm REAL,
    weight_kg REAL,
    goal TEXT,
    years_experience INTEGER,
    coach_status TEXT CHECK (coach_status IN ('pending', 'approved', 'rejected')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',
  '''
  CREATE TABLE coach_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    coach_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    certificate_path TEXT,
    ai_score INTEGER,
    ai_verdict TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
      CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',

  // ---------- Training ----------
   '''
  CREATE TABLE exercises (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    muscle_group TEXT NOT NULL,
    equipment TEXT,
    level TEXT,
    description TEXT,
    instructions TEXT,
    default_sets INTEGER,
    default_reps INTEGER,
    media_path TEXT,
    created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'approved'
      CHECK (status IN ('approved', 'pending', 'refused')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',
   '''
  CREATE TABLE programs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('workout', 'nutrition')),
    goal TEXT,
    intensity TEXT,
    weeks INTEGER,
    days_per_week INTEGER,
    minutes_per_session INTEGER,
    description TEXT,
    kcal_target INTEGER,
    protein_pct INTEGER,
    carbs_pct INTEGER,
    fat_pct INTEGER,
    created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'approved'
      CHECK (status IN ('approved', 'pending', 'refused')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',
  '''
  CREATE TABLE program_days (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    program_id INTEGER NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    day_index INTEGER NOT NULL,
    title TEXT NOT NULL,
    is_rest INTEGER NOT NULL DEFAULT 0
  )
  ''',
  '''
  CREATE TABLE program_exercises (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    program_day_id INTEGER NOT NULL REFERENCES program_days(id) ON DELETE CASCADE,
    exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
    sets INTEGER NOT NULL,
    reps INTEGER NOT NULL,
    position INTEGER NOT NULL
  )
  ''',
  '''
  CREATE TABLE user_programs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    program_id INTEGER NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    started_on TEXT NOT NULL,
    UNIQUE (user_id, program_id)
  )
  ''',

  // ---------- Nutrition ----------
  '''
  CREATE TABLE foods (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    kcal_per_100g REAL NOT NULL,
    protein_g REAL NOT NULL DEFAULT 0,
    carbs_g REAL NOT NULL DEFAULT 0,
    fat_g REAL NOT NULL DEFAULT 0,
    created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'approved'
      CHECK (status IN ('approved', 'pending', 'refused')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',
  '''
  CREATE TABLE meal_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    food_id INTEGER NOT NULL REFERENCES foods(id) ON DELETE RESTRICT,
    grams REAL NOT NULL,
    meal_type TEXT NOT NULL
      CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    logged_on TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',
  '''
  CREATE TABLE supplements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    timing TEXT
  )
  ''',
  '''
  CREATE TABLE supplement_alternatives (
    supplement_id INTEGER NOT NULL REFERENCES supplements(id) ON DELETE CASCADE,
    food_id INTEGER NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
    PRIMARY KEY (supplement_id, food_id)
  )
  ''',

  // ---------- Store ----------
  '''
  CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL CHECK (category IN ('training_gear', 'supplement')),
    condition TEXT NOT NULL CHECK (condition IN ('new', 'used')),
    price_tnd REAL NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    source TEXT NOT NULL CHECK (source IN ('app_store', 'community')),
    seller_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'approved'
      CHECK (status IN ('approved', 'pending', 'refused')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',

  // ---------- Coaching ----------
  '''
  CREATE TABLE bookings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    coach_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    starts_at TEXT NOT NULL,
    mode TEXT NOT NULL CHECK (mode IN ('online', 'in_person')),
    price_tnd REAL NOT NULL,
    payment TEXT NOT NULL CHECK (payment IN ('online', 'cash')),
    status TEXT NOT NULL DEFAULT 'pending'
      CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled', 'ended')),
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',
  '''
  CREATE TABLE messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    booking_id INTEGER NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    sender_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    sent_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',

  // ---------- Progress ----------
  '''
  CREATE TABLE weekly_checkins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    week_no INTEGER NOT NULL,
    check_date TEXT NOT NULL,
    weight_kg REAL,
    waist_cm REAL,
    chest_cm REAL,
    workouts_done INTEGER,
    workouts_planned INTEGER,
    energy INTEGER CHECK (energy BETWEEN 1 AND 5),
    notes TEXT,
    photo_path TEXT,
    UNIQUE (user_id, week_no)
  )
  ''',

  // ---------- Admin request inbox ----------
  // Every user or coach change waits here until an admin accepts or refuses it.
  '''
  CREATE TABLE content_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_type TEXT NOT NULL,
    target_table TEXT NOT NULL,
    target_id INTEGER,
    payload TEXT,
    submitted_by INTEGER REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending'
      CHECK (status IN ('pending', 'accepted', 'refused')),
    decided_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )
  ''',

  // ---------- Indexes for the screens that filter or sort ----------
  'CREATE INDEX idx_coach_requests_status ON coach_requests(status)',
  'CREATE INDEX idx_exercises_status ON exercises(status)',
  'CREATE INDEX idx_program_days_program ON program_days(program_id)',
  'CREATE INDEX idx_program_exercises_day ON program_exercises(program_day_id)',
  'CREATE INDEX idx_meal_logs_user_day ON meal_logs(user_id, logged_on)',
  'CREATE INDEX idx_bookings_coach_start ON bookings(coach_id, starts_at)',
  'CREATE INDEX idx_messages_booking ON messages(booking_id)',
  'CREATE INDEX idx_checkins_user ON weekly_checkins(user_id)',
  'CREATE INDEX idx_content_requests_status ON content_requests(status)',
];

const List<String> coachSchedulingStatements = [
  '''
  CREATE TABLE coach_availability (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    coach_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    weekday INTEGER NOT NULL CHECK (weekday BETWEEN 1 AND 7),
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    slot_minutes INTEGER NOT NULL CHECK (slot_minutes > 0),
    mode TEXT NOT NULL CHECK (mode IN ('online', 'in_person')),
    price_tnd REAL NOT NULL CHECK (price_tnd >= 0)
  )
  ''',
  '''
  CREATE TABLE coach_slots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    coach_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    availability_id INTEGER REFERENCES coach_availability(id) ON DELETE SET NULL,
    starts_at TEXT NOT NULL,
    mode TEXT NOT NULL CHECK (mode IN ('online', 'in_person')),
    price_tnd REAL NOT NULL CHECK (price_tnd >= 0),
    status TEXT NOT NULL DEFAULT 'free'
      CHECK (status IN ('free', 'pending', 'booked')),
    UNIQUE (coach_id, starts_at)
  )
  ''',
  'CREATE INDEX idx_coach_slots_coach_start ON coach_slots(coach_id, starts_at, status)',
  'CREATE INDEX idx_coach_availability_coach_day ON coach_availability(coach_id, weekday)',
];

const List<String> coachingTriggerStatements = [
  '''
  CREATE TRIGGER booking_slot_insert_guard
  BEFORE INSERT ON bookings
  WHEN NEW.status = 'pending'
  BEGIN
    SELECT CASE WHEN julianday(NEW.starts_at) <= julianday('now', 'localtime')
      OR NOT EXISTS (
        SELECT 1 FROM coach_slots
        WHERE coach_id = NEW.coach_id AND starts_at = NEW.starts_at
          AND status = 'free' AND mode = NEW.mode AND price_tnd = NEW.price_tnd
      )
      THEN RAISE(ABORT, 'Booking slot is unavailable') END;
  END
  ''',
  '''
  CREATE TRIGGER booking_slot_after_insert
  AFTER INSERT ON bookings
  WHEN NEW.status = 'pending'
  BEGIN
    UPDATE coach_slots SET status = 'pending'
    WHERE coach_id = NEW.coach_id AND starts_at = NEW.starts_at AND status = 'free';
  END
  ''',
  '''
  CREATE TRIGGER booking_slot_update_guard
  BEFORE UPDATE OF coach_id, starts_at, status ON bookings
  WHEN NEW.status IN ('pending', 'accepted')
  BEGIN
    SELECT CASE WHEN julianday(NEW.starts_at) <= julianday('now', 'localtime')
      OR NOT EXISTS (
        SELECT 1 FROM coach_slots
        WHERE coach_id = NEW.coach_id
          AND starts_at = NEW.starts_at
          AND mode = NEW.mode
          AND price_tnd = NEW.price_tnd
          AND (
            status = 'free'
            OR (coach_id = OLD.coach_id AND starts_at = OLD.starts_at)
          )
      )
      THEN RAISE(ABORT, 'Booking slot is unavailable') END;
  END
  ''',
  '''
  CREATE TRIGGER booking_slot_after_update
  AFTER UPDATE OF coach_id, starts_at, status ON bookings
  BEGIN
    UPDATE coach_slots SET status = 'free'
    WHERE coach_id = OLD.coach_id
      AND starts_at = OLD.starts_at
      AND (
        NEW.coach_id != OLD.coach_id
        OR NEW.starts_at != OLD.starts_at
        OR NEW.status IN ('cancelled', 'declined', 'ended')
      );
    UPDATE coach_slots
    SET status = CASE NEW.status WHEN 'pending' THEN 'pending' ELSE 'booked' END
    WHERE coach_id = NEW.coach_id
      AND starts_at = NEW.starts_at
      AND NEW.status IN ('pending', 'accepted');
  END
  ''',
];

const List<String> coachSchedulingBackfillStatements = [
  '''
  INSERT OR IGNORE INTO coach_slots
    (coach_id, starts_at, mode, price_tnd, status)
  SELECT coach_id, starts_at, mode, price_tnd,
         CASE WHEN MAX(CASE WHEN status = 'accepted' THEN 1 ELSE 0 END) = 1
           THEN 'booked' ELSE 'pending' END
  FROM bookings
  WHERE status IN ('pending', 'accepted')
    AND julianday(starts_at) > julianday('now', 'localtime')
  GROUP BY coach_id, starts_at
  ''',
];