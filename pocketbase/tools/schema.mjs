const DT = (name, o = {}) => ({ type: 'date', name, required: !!o.required });
const TXT = (name, o = {}) => ({
  type: 'text', name, required: !!o.required, min: o.min ?? 0, max: o.max ?? 0, pattern: o.pattern ?? '',
});
const NUM = (name, o = {}) => ({
  type: 'number', name, required: !!o.required, min: o.min ?? null, max: o.max ?? null, onlyInt: o.int ?? false,
});
const BOOL = (name) => ({ type: 'bool', name });
const SEL = (name, values, o = {}) => ({
  type: 'select', name, required: !!o.required, maxSelect: 1, values,
});
const REL = (name, target, o = {}) => ({
  type: 'relation', name, required: !!o.required, target, maxSelect: o.multi ? 999 : 1, minSelect: 0,
  cascadeDelete: false,
});
const AUTO = [
  { type: 'autodate', name: 'created', onCreate: true, onUpdate: false },
  { type: 'autodate', name: 'updated', onCreate: true, onUpdate: true },
];

const AUTH = '@request.auth.id != ""';
const ADMIN = '@request.auth.role = "admin"';
const INSTR = '@request.auth.role = "instructor"';
const STAFF = `(${ADMIN} || ${INSTR})`;
const ND = 'deleted = false';

export const PHONE_RE = '^\\+7\\d{10}$';
export const PLATE_RE = '^([АВЕКМНОРСТУХ]\\d{3}[АВЕКМНОРСТУХ]{2}|\\d{4}[АВЕКМНОРСТУХ]{2})\\d{2,3}$';

export const COLLECTIONS = [
  {
    name: 'categories',
    fields: [
      TXT('code', { required: true, min: 1, max: 4, pattern: '^[A-Za-z0-9]{1,4}$' }),
      TXT('title', { required: true, min: 3, max: 80 }),
      NUM('min_age', { required: true, min: 14, max: 30, int: true }),
      NUM('theory_hours', { required: true, min: 1, max: 500, int: true }),
      NUM('practice_hours', { required: true, min: 1, max: 500, int: true }),
      NUM('price', { required: true, min: 1, max: 1000000, int: true }),
      TXT('description', { max: 500 }),
      BOOL('deleted'),
    ],
    indexes: ['CREATE UNIQUE INDEX `idx_categories_code` ON `categories` (`code`)'],
    rules: {
      list: `${ADMIN} || ${ND}`, view: `${ADMIN} || ${ND}`,
      create: ADMIN, update: ADMIN, delete: ADMIN,
    },
  },
  {
    name: 'cadets',
    fields: [
      REL('user', 'users', { required: true }),
      TXT('full_name', { required: true, min: 5, max: 100 }),
      DT('birth_date', { required: true }),
      TXT('phone', { required: true, pattern: PHONE_RE }),
      REL('category', 'categories', { required: true }),
      SEL('status', ['studying', 'graduated', 'expelled'], { required: true }),
      DT('enrolled_at', { required: true }),
      BOOL('deleted'),
    ],
    indexes: ['CREATE UNIQUE INDEX `idx_cadets_user` ON `cadets` (`user`)'],
    rules: {
      list: `${ADMIN} || ((${INSTR} || user = @request.auth.id) && ${ND})`,
      view: `${ADMIN} || ((${INSTR} || user = @request.auth.id) && ${ND})`,
      create: `${ADMIN} || (@request.auth.role = "cadet" && @request.body.user = @request.auth.id && @request.body.status = "studying")`,
      update: `${ADMIN} || (user = @request.auth.id && @request.body.user:isset = false && @request.body.status:isset = false && @request.body.category:isset = false && @request.body.enrolled_at:isset = false && @request.body.deleted:isset = false)`,
      delete: ADMIN,
    },
  },
  {
    name: 'medical_certificates',
    fields: [
      REL('cadet', 'cadets', { required: true }),
      TXT('number', { required: true, min: 4, max: 30 }),
      DT('issued_at', { required: true }),
      DT('valid_until', { required: true }),
      TXT('clinic', { required: true, min: 3, max: 120 }),
      BOOL('deleted'),
    ],
    indexes: ['CREATE UNIQUE INDEX `idx_medical_cadet` ON `medical_certificates` (`cadet`)'],
    rules: {
      list: `${ADMIN} || ((${INSTR} || cadet.user = @request.auth.id) && ${ND})`,
      view: `${ADMIN} || ((${INSTR} || cadet.user = @request.auth.id) && ${ND})`,
      create: ADMIN, update: ADMIN, delete: ADMIN,
    },
  },
  {
    name: 'instructors',
    fields: [
      REL('user', 'users', { required: true }),
      TXT('full_name', { required: true, min: 5, max: 100 }),
      TXT('phone', { required: true, pattern: PHONE_RE }),
      NUM('experience_years', { min: 0, max: 60, int: true }),
      TXT('license_no', { required: true, pattern: '^\\d{4} \\d{6}$' }),
      REL('categories', 'categories', { multi: true, required: true }),
      DT('hired_at', { required: true }),
      BOOL('deleted'),
    ],
    indexes: ['CREATE UNIQUE INDEX `idx_instructors_user` ON `instructors` (`user`)'],
    rules: {
      list: `${ADMIN} || (${AUTH} && ${ND})`, view: `${ADMIN} || (${AUTH} && ${ND})`,
      create: ADMIN, update: ADMIN, delete: ADMIN,
    },
  },
  {
    name: 'cars',
    fields: [
      TXT('plate', { required: true, pattern: PLATE_RE }),
      TXT('model', { required: true, min: 2, max: 80 }),
      NUM('year', { required: true, min: 1990, max: 2100, int: true }),
      REL('category', 'categories', { required: true }),
      SEL('transmission', ['manual', 'auto'], { required: true }),
      NUM('mileage', { min: 0, max: 2000000, int: true }),
      SEL('status', ['active', 'service', 'retired'], { required: true }),
      DT('next_service', {}),
      BOOL('deleted'),
    ],
    indexes: ['CREATE UNIQUE INDEX `idx_cars_plate` ON `cars` (`plate`)'],
    rules: {
      list: `${ADMIN} || (${AUTH} && ${ND})`, view: `${ADMIN} || (${AUTH} && ${ND})`,
      create: ADMIN, update: ADMIN, delete: ADMIN,
    },
  },
  {
    name: 'groups',
    fields: [
      TXT('name', { required: true, min: 2, max: 60 }),
      REL('category', 'categories', { required: true }),
      REL('curator', 'instructors', {}),
      DT('starts_at', { required: true }),
      DT('ends_at', { required: true }),
      REL('cadets', 'cadets', { multi: true }),
      BOOL('deleted'),
    ],
    indexes: ['CREATE UNIQUE INDEX `idx_groups_name` ON `groups` (`name`)'],
    rules: {
      list: `${ADMIN} || ((${INSTR} || cadets.user ?= @request.auth.id) && ${ND})`,
      view: `${ADMIN} || ((${INSTR} || cadets.user ?= @request.auth.id) && ${ND})`,
      create: ADMIN, update: ADMIN, delete: ADMIN,
    },
  },
  {
    name: 'lessons',
    fields: [
      REL('cadet', 'cadets', { required: true }),
      REL('instructor', 'instructors', { required: true }),
      REL('car', 'cars', { required: true }),
      DT('starts_at', { required: true }),
      DT('ends_at', { required: true }),
      SEL('kind', ['ground', 'city'], { required: true }),
      SEL('status', ['planned', 'done', 'cancelled', 'no_show'], { required: true }),
      NUM('rating', { min: 1, max: 5, int: true }),
      TXT('notes', { max: 500 }),
      BOOL('deleted'),
    ],
    indexes: [
      'CREATE INDEX `idx_lessons_start` ON `lessons` (`starts_at`)',
      'CREATE INDEX `idx_lessons_cadet` ON `lessons` (`cadet`)',
      'CREATE INDEX `idx_lessons_instructor` ON `lessons` (`instructor`)',
      'CREATE INDEX `idx_lessons_car` ON `lessons` (`car`)',
    ],
    rules: {
      list: `${ADMIN} || ((instructor.user = @request.auth.id || cadet.user = @request.auth.id) && ${ND})`,
      view: `${ADMIN} || ((instructor.user = @request.auth.id || cadet.user = @request.auth.id) && ${ND})`,
      create: `${ADMIN} || ${INSTR} || (@request.auth.role = "cadet" && @request.body.status = "planned")`,
      update: `${ADMIN} || instructor.user = @request.auth.id || (cadet.user = @request.auth.id && status = "planned" && @request.body.status = "cancelled")`,
      delete: ADMIN,
    },
  },
  {
    name: 'exams',
    fields: [
      REL('cadet', 'cadets', { required: true }),
      SEL('type', ['theory', 'ground', 'city'], { required: true }),
      DT('exam_date', { required: true }),
      SEL('result', ['scheduled', 'passed', 'failed', 'no_show'], { required: true }),
      NUM('score', { min: 0, max: 100, int: true }),
      NUM('attempt', { required: true, min: 1, max: 20, int: true }),
      TXT('examiner', { max: 100 }),
      BOOL('deleted'),
    ],
    indexes: ['CREATE INDEX `idx_exams_cadet` ON `exams` (`cadet`)'],
    rules: {
      list: `${ADMIN} || ((${INSTR} || cadet.user = @request.auth.id) && ${ND})`,
      view: `${ADMIN} || ((${INSTR} || cadet.user = @request.auth.id) && ${ND})`,
      create: STAFF, update: STAFF, delete: ADMIN,
    },
  },
  {
    name: 'payments',
    fields: [
      REL('cadet', 'cadets', { required: true }),
      NUM('amount', { required: true, min: 1, max: 1000000, int: true }),
      DT('paid_at', { required: true }),
      SEL('method', ['cash', 'card', 'transfer'], { required: true }),
      SEL('purpose', ['tuition', 'retake', 'extra_lesson'], { required: true }),
      TXT('comment', { max: 300 }),
      BOOL('deleted'),
    ],
    indexes: ['CREATE INDEX `idx_payments_cadet` ON `payments` (`cadet`)'],
    rules: {
      list: `${ADMIN} || (cadet.user = @request.auth.id && ${ND})`,
      view: `${ADMIN} || (cadet.user = @request.auth.id && ${ND})`,
      create: ADMIN, update: ADMIN, delete: ADMIN,
    },
  },
];

export const AUTO_FIELDS = AUTO;

export const USERS_ROLE_FIELD = SEL('role', ['admin', 'instructor', 'cadet'], { required: true });
export const USERS_RULES = {
  list: `${ADMIN} || id = @request.auth.id`,
  view: `${ADMIN} || id = @request.auth.id`,
  create: `@request.body.role = "cadet" || ${ADMIN}`,
  update: `${ADMIN} || (id = @request.auth.id && @request.body.role:isset = false)`,
  delete: ADMIN,
};
