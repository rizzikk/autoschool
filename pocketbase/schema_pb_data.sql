CREATE TABLE `cadets` (`birth_date` TEXT DEFAULT '' NOT NULL, `category` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `enrolled_at` TEXT DEFAULT '' NOT NULL, `full_name` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `phone` TEXT DEFAULT '' NOT NULL, `status` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `user` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `cars` (`category` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `mileage` NUMERIC DEFAULT 0 NOT NULL, `model` TEXT DEFAULT '' NOT NULL, `next_service` TEXT DEFAULT '' NOT NULL, `plate` TEXT DEFAULT '' NOT NULL, `status` TEXT DEFAULT '' NOT NULL, `transmission` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `year` NUMERIC DEFAULT 0 NOT NULL);

CREATE TABLE `categories` (`code` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `description` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `min_age` NUMERIC DEFAULT 0 NOT NULL, `practice_hours` NUMERIC DEFAULT 0 NOT NULL, `price` NUMERIC DEFAULT 0 NOT NULL, `theory_hours` NUMERIC DEFAULT 0 NOT NULL, `title` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `exams` (`attempt` NUMERIC DEFAULT 0 NOT NULL, `cadet` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `exam_date` TEXT DEFAULT '' NOT NULL, `examiner` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `result` TEXT DEFAULT '' NOT NULL, `score` NUMERIC DEFAULT 0 NOT NULL, `type` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `groups` (`cadets` JSON DEFAULT '[]' NOT NULL, `category` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `curator` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `ends_at` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `starts_at` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `instructors` (`categories` JSON DEFAULT '[]' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `experience_years` NUMERIC DEFAULT 0 NOT NULL, `full_name` TEXT DEFAULT '' NOT NULL, `hired_at` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `license_no` TEXT DEFAULT '' NOT NULL, `phone` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `user` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `lessons` (`cadet` TEXT DEFAULT '' NOT NULL, `car` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `ends_at` TEXT DEFAULT '' NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `instructor` TEXT DEFAULT '' NOT NULL, `kind` TEXT DEFAULT '' NOT NULL, `notes` TEXT DEFAULT '' NOT NULL, `rating` NUMERIC DEFAULT 0 NOT NULL, `starts_at` TEXT DEFAULT '' NOT NULL, `status` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `medical_certificates` (`cadet` TEXT DEFAULT '' NOT NULL, `clinic` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `issued_at` TEXT DEFAULT '' NOT NULL, `number` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `valid_until` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `payments` (`amount` NUMERIC DEFAULT 0 NOT NULL, `cadet` TEXT DEFAULT '' NOT NULL, `comment` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `deleted` BOOLEAN DEFAULT FALSE NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `method` TEXT DEFAULT '' NOT NULL, `paid_at` TEXT DEFAULT '' NOT NULL, `purpose` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL);

CREATE TABLE `users` (`avatar` TEXT DEFAULT '' NOT NULL, `created` TEXT DEFAULT '' NOT NULL, `email` TEXT DEFAULT '' NOT NULL, `emailVisibility` BOOLEAN DEFAULT FALSE NOT NULL, `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL, `name` TEXT DEFAULT '' NOT NULL, `password` TEXT DEFAULT '' NOT NULL, `tokenKey` TEXT DEFAULT '' NOT NULL, `updated` TEXT DEFAULT '' NOT NULL, `verified` BOOLEAN DEFAULT FALSE NOT NULL, "role" TEXT DEFAULT '' NOT NULL);

CREATE INDEX idx__collections_type on `_collections` (`type`);

CREATE UNIQUE INDEX `idx_authOrigins_unique_pairs` ON `_authOrigins` (
  `collectionRef`,
  `recordRef`,
  `fingerprint`
);

CREATE UNIQUE INDEX `idx_cadets_user` ON `cadets` (`user`);

CREATE UNIQUE INDEX `idx_cars_plate` ON `cars` (`plate`);

CREATE UNIQUE INDEX `idx_categories_code` ON `categories` (`code`);

CREATE UNIQUE INDEX `idx_email__pb_users_auth_` ON `users` (`email`) WHERE `email` != '';

CREATE UNIQUE INDEX `idx_email_pbc_3142635823` ON `_superusers` (`email`) WHERE `email` != '';

CREATE INDEX `idx_exams_cadet` ON `exams` (`cadet`);

CREATE UNIQUE INDEX `idx_externalAuths_collection_provider` ON `_externalAuths` (
  `collectionRef`,
  `provider`,
  `providerId`
);

CREATE UNIQUE INDEX `idx_externalAuths_record_provider` ON `_externalAuths` (
  `collectionRef`,
  `recordRef`,
  `provider`
);

CREATE UNIQUE INDEX `idx_groups_name` ON `groups` (`name`);

CREATE UNIQUE INDEX `idx_instructors_user` ON `instructors` (`user`);

CREATE INDEX `idx_lessons_cadet` ON `lessons` (`cadet`);

CREATE INDEX `idx_lessons_car` ON `lessons` (`car`);

CREATE INDEX `idx_lessons_instructor` ON `lessons` (`instructor`);

CREATE INDEX `idx_lessons_start` ON `lessons` (`starts_at`);

CREATE UNIQUE INDEX `idx_medical_cadet` ON `medical_certificates` (`cadet`);

CREATE INDEX `idx_mfas_collectionRef_recordRef` ON `_mfas` (
  `collectionRef`,
  `recordRef`
);

CREATE INDEX `idx_otps_collectionRef_recordRef` ON `_otps` (
  `collectionRef`,
  `recordRef`
);

CREATE INDEX `idx_payments_cadet` ON `payments` (`cadet`);

CREATE UNIQUE INDEX `idx_tokenKey__pb_users_auth_` ON `users` (`tokenKey`);

CREATE UNIQUE INDEX `idx_tokenKey_pbc_3142635823` ON `_superusers` (`tokenKey`);
