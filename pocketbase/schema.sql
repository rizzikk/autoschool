PRAGMA foreign_keys = ON;

CREATE TABLE users (
  id        TEXT PRIMARY KEY,
  email     TEXT NOT NULL UNIQUE,
  name      TEXT NOT NULL DEFAULT '',
  role      TEXT NOT NULL CHECK (role IN ('admin', 'instructor', 'cadet')),
  created   TEXT NOT NULL,
  updated   TEXT NOT NULL
);

CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  code TEXT NOT NULL CHECK (length(code) BETWEEN 1 AND 4),
  title TEXT NOT NULL CHECK (length(title) BETWEEN 3 AND 80),
  min_age INTEGER NOT NULL CHECK (min_age BETWEEN 14 AND 30),
  theory_hours INTEGER NOT NULL CHECK (theory_hours BETWEEN 1 AND 500),
  practice_hours INTEGER NOT NULL CHECK (practice_hours BETWEEN 1 AND 500),
  price INTEGER NOT NULL CHECK (price BETWEEN 1 AND 1000000),
  description TEXT CHECK ((description IS NULL OR length(description) BETWEEN 0 AND 500)),
  deleted BOOLEAN NOT NULL DEFAULT 0,
  created TEXT NOT NULL,
  updated TEXT NOT NULL
);
CREATE UNIQUE INDEX `idx_categories_code` ON `categories` (`code`);

CREATE TABLE cadets (
  id TEXT PRIMARY KEY,
  user TEXT NOT NULL REFERENCES users(id),
  full_name TEXT NOT NULL CHECK (length(full_name) BETWEEN 5 AND 100),
  birth_date TEXT NOT NULL,
  phone TEXT NOT NULL,
  category TEXT NOT NULL REFERENCES categories(id),
  status TEXT NOT NULL CHECK (status IN ('studying', 'graduated', 'expelled')),
  enrolled_at TEXT NOT NULL,
  deleted BOOLEAN NOT NULL DEFAULT 0,
  created TEXT NOT NULL,
  updated TEXT NOT NULL
);
CREATE UNIQUE INDEX `idx_cadets_user` ON `cadets` (`user`);

CREATE TABLE medical_certificates (
  id TEXT PRIMARY KEY,
  cadet TEXT NOT NULL REFERENCES cadets(id),
  number TEXT NOT NULL CHECK (length(number) BETWEEN 4 AND 30),
  issued_at TEXT NOT NULL,
  valid_until TEXT NOT NULL,
  clinic TEXT NOT NULL CHECK (length(clinic) BETWEEN 3 AND 120),
  deleted BOOLEAN NOT NULL DEFAULT 0,
  created TEXT NOT NULL,
  updated TEXT NOT NULL
);
CREATE UNIQUE INDEX `idx_medical_cadet` ON `medical_certificates` (`cadet`);

CREATE TABLE instructors (
  id TEXT PRIMARY KEY,
  user TEXT NOT NULL REFERENCES users(id),
  full_name TEXT NOT NULL CHECK (length(full_name) BETWEEN 5 AND 100),
  phone TEXT NOT NULL,
  experience_years INTEGER CHECK ((experience_years IS NULL OR experience_years BETWEEN 0 AND 60)),
  license_no TEXT NOT NULL,
  categories TEXT NOT NULL,
  hired_at TEXT NOT NULL,
  deleted BOOLEAN NOT NULL DEFAULT 0,
  created TEXT NOT NULL,
  updated TEXT NOT NULL
);
CREATE UNIQUE INDEX `idx_instructors_user` ON `instructors` (`user`);

CREATE TABLE cars (
  id TEXT PRIMARY KEY,
  plate TEXT NOT NULL,
  model TEXT NOT NULL CHECK (length(model) BETWEEN 2 AND 80),
  year INTEGER NOT NULL CHECK (year BETWEEN 1990 AND 2100),
  category TEXT NOT NULL REFERENCES categories(id),
  transmission TEXT NOT NULL CHECK (transmission IN ('manual', 'auto')),
  mileage INTEGER CHECK ((mileage IS NULL OR mileage BETWEEN 0 AND 2000000)),
  status TEXT NOT NULL CHECK (status IN ('active', 'service', 'retired')),
  next_service TEXT,
  deleted BOOLEAN NOT NULL DEFAULT 0,
  created TEXT NOT NULL,
  updated TEXT NOT NULL
);
CREATE UNIQUE INDEX `idx_cars_plate` ON `cars` (`plate`);

CREATE TABLE groups (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL CHECK (length(name) BETWEEN 2 AND 60),
  category TEXT NOT NULL REFERENCES categories(id),
  curator TEXT REFERENCES instructors(id),
  starts_at TEXT NOT NULL,
  ends_at TEXT NOT NULL,
  cadets TEXT,
  deleted BOOLEAN NOT NULL DEFAULT 0,
  created TEXT NOT NULL,
  updated TEXT NOT NULL
);
CREATE UNIQUE INDEX `idx_groups_name` ON `groups` (`name`);

CREATE TABLE lessons (
  id TEXT PRIMARY KEY,
  cadet TEXT NOT NULL REFERENCES cadets(id),
  instructor TEXT NOT NULL REFERENCES instructors(id),
  car TEXT NOT NULL REFERENCES cars(id),
  starts_at TEXT NOT NULL,
  ends_at TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('ground', 'city')),
  status TEXT NOT NULL CHECK (status IN ('planned', 'done', 'cancelled', 'no_show')),
  rating INTEGER CHECK ((rating IS NULL OR rating BETWEEN 1 AND 5)),
  notes TEXT CHECK ((notes IS NULL OR length(notes) BETWEEN 0 AND 500)),
  deleted BOOLEAN NOT NULL DEFAULT 0,
  created TEXT NOT NULL,
  updated TEXT NOT NULL
);
CREATE INDEX `idx_lessons_start` ON `lessons` (`starts_at`);
CREATE INDEX `idx_lessons_cadet` ON `lessons` (`cadet`);
CREATE INDEX `idx_lessons_instructor` ON `lessons` (`instructor`);
CREATE INDEX `idx_lessons_car` ON `lessons` (`car`);

CREATE TABLE exams (
  id TEXT PRIMARY KEY,
  cadet TEXT NOT NULL REFERENCES cadets(id),
  type TEXT NOT NULL CHECK (type IN ('theory', 'ground', 'city')),
  exam_date TEXT NOT NULL,
  result TEXT NOT NULL CHECK (result IN ('scheduled', 'passed', 'failed', 'no_show')),
  score INTEGER CHECK ((score IS NULL OR score BETWEEN 0 AND 100)),
  attempt INTEGER NOT NULL CHECK (attempt BETWEEN 1 AND 20),
  examiner TEXT CHECK ((examiner IS NULL OR length(examiner) BETWEEN 0 AND 100)),
  deleted BOOLEAN NOT NULL DEFAULT 0,
  created TEXT NOT NULL,
  updated TEXT NOT NULL
);
CREATE INDEX `idx_exams_cadet` ON `exams` (`cadet`);

CREATE TABLE payments (
  id TEXT PRIMARY KEY,
  cadet TEXT NOT NULL REFERENCES cadets(id),
  amount INTEGER NOT NULL CHECK (amount BETWEEN 1 AND 1000000),
  paid_at TEXT NOT NULL,
  method TEXT NOT NULL CHECK (method IN ('cash', 'card', 'transfer')),
  purpose TEXT NOT NULL CHECK (purpose IN ('tuition', 'retake', 'extra_lesson')),
  comment TEXT CHECK ((comment IS NULL OR length(comment) BETWEEN 0 AND 300)),
  deleted BOOLEAN NOT NULL DEFAULT 0,
  created TEXT NOT NULL,
  updated TEXT NOT NULL
);
CREATE INDEX `idx_payments_cadet` ON `payments` (`cadet`);

