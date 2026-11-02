import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const schema = JSON.parse(readFileSync(join(root, 'pb_schema.json'), 'utf8'));
const byId = Object.fromEntries(schema.map((c) => [c.id, c]));
byId['_pb_users_auth_'] = schema.find((c) => c.name === 'users');

const TITLES = {
  users: 'Учётные записи', categories: 'Категории', cadets: 'Курсанты',
  medical_certificates: 'Медицинские справки', instructors: 'Инструкторы', cars: 'Автомобили',
  groups: 'Учебные группы', lessons: 'Занятия вождением', exams: 'Экзамены', payments: 'Платежи',
};
const SKIP = new Set(['id', 'created', 'updated', 'password', 'tokenKey', 'email', 'emailVisibility', 'verified']);

function sqlType(f) {
  switch (f.type) {
    case 'number': return f.onlyInt ? 'INTEGER' : 'REAL';
    case 'bool': return 'BOOLEAN';
    case 'relation': return f.maxSelect > 1 ? 'TEXT' : 'TEXT';
    case 'autodate': case 'date': return 'TEXT';
    case 'json': return 'TEXT';
    default: return 'TEXT';
  }
}

function describe(f) {
  const parts = [];
  if (f.type === 'text') {
    if (f.min || f.max) parts.push(`длина ${f.min || 0}–${f.max || '∞'}`);
    if (f.pattern) parts.push(`шаблон ${f.pattern}`);
  }
  if (f.type === 'number') {
    if (f.min != null || f.max != null) parts.push(`от ${f.min ?? '−∞'} до ${f.max ?? '∞'}`);
    if (f.onlyInt) parts.push('целое');
  }
  if (f.type === 'select') parts.push(`значения: ${f.values.join(', ')}`);
  if (f.type === 'relation') {
    const t = byId[f.collectionId]?.name ?? '?';
    parts.push(f.maxSelect > 1 ? `связь «многие ко многим» с ${t}` : `ссылка на ${t}`);
  }
  if (f.type === 'date') parts.push('дата и время UTC');
  return parts.join('; ');
}

const TYPE_RU = {
  text: 'строка', number: 'число', bool: 'логическое', date: 'дата', select: 'выбор',
  relation: 'связь', autodate: 'дата', json: 'JSON', email: 'почта', password: 'пароль',
};

let sql = `PRAGMA foreign_keys = ON;

`;
for (const c of schema) {
  if (c.name === 'users') {
    sql += `CREATE TABLE users (
  id        TEXT PRIMARY KEY,
  email     TEXT NOT NULL UNIQUE,
  name      TEXT NOT NULL DEFAULT '',
  role      TEXT NOT NULL CHECK (role IN ('admin', 'instructor', 'cadet')),
  created   TEXT NOT NULL,
  updated   TEXT NOT NULL
);

`;
    continue;
  }
  const lines = ['  id TEXT PRIMARY KEY'];
  for (const f of c.fields) {
    if (SKIP.has(f.name)) continue;
    let line = `  ${f.name} ${sqlType(f)}`;
    const checks = [];
    if (f.required && f.type !== 'bool') line += ' NOT NULL';
    if (f.type === 'bool') line += ' NOT NULL DEFAULT 0';
    if (f.type === 'text' && (f.min || f.max)) {
      const lo = f.min || 0;
      checks.push(f.max ? `length(${f.name}) BETWEEN ${lo} AND ${f.max}` : `length(${f.name}) >= ${lo}`);
      if (!f.required) checks[0] = `(${f.name} IS NULL OR ${checks[0]})`;
    }
    if (f.type === 'number' && (f.min != null || f.max != null)) {
      const lo = f.min ?? -1e18, hi = f.max ?? 1e18;
      checks.push(`${f.name} BETWEEN ${lo} AND ${hi}`);
      if (!f.required) checks[checks.length - 1] = `(${f.name} IS NULL OR ${checks[checks.length - 1]})`;
    }
    if (f.type === 'select') checks.push(`${f.name} IN (${f.values.map((v) => `'${v}'`).join(', ')})`);
    if (f.type === 'relation' && f.maxSelect === 1) {
      const t = byId[f.collectionId].name;
      line += ` REFERENCES ${t}(id)`;
    }
    if (checks.length) line += ` CHECK (${checks.join(' AND ')})`;
    lines.push(line);
  }
  lines.push('  created TEXT NOT NULL');
  lines.push('  updated TEXT NOT NULL');
  const body = lines.map((l, i) => (i < lines.length - 1 ? `${l},` : l)).join('\n');
  sql += `CREATE TABLE ${c.name} (\n${body}\n);\n`;
  for (const ix of c.indexes ?? []) sql += `${ix};\n`;
  sql += '\n';
}
writeFileSync(join(root, 'schema.sql'), sql, 'utf8');

let md = `# Словарь данных автошколы\n\nФайл построен из pb_schema.json скриптом tools/export_sql.mjs. Типы: «выбор» — одно из заданных значений, «связь» — ссылка на запись другой коллекции.\n\n`;
for (const c of schema) {
  md += `## ${c.name} — ${TITLES[c.name] ?? c.name}\n\n| Поле | Тип | Обязательно | Ограничения |\n|---|---|---|---|\n`;
  for (const f of c.fields) {
    if (SKIP.has(f.name)) continue;
    md += `| ${f.name} | ${TYPE_RU[f.type] ?? f.type} | ${f.required ? 'да' : 'нет'} | ${describe(f).replace(/\|/g, '\\|')} |\n`;
  }
  if (c.indexes?.length) md += `\nИндексы:\n\n${c.indexes.map((i) => '- ' + i.replace(/`/g, '')).join('\n')}\n`;
  md += '\nПравила доступа:\n\n';
  for (const [k, n] of [['listRule', 'список'], ['viewRule', 'просмотр'], ['createRule', 'создание'], ['updateRule', 'изменение'], ['deleteRule', 'удаление']]) {
    const r = c[k];
    md += `- ${n}: ${r === null ? 'только суперпользователь' : r === '' ? 'открыто всем' : '`' + r + '`'}\n`;
  }
  md += '\n';
}
writeFileSync(join(root, 'схема.md'), md, 'utf8');
console.log('schema.sql и схема.md записаны');

const dbArg = process.argv.indexOf('--db');
if (dbArg > 0) {
  try {
    const { DatabaseSync } = await import('node:sqlite');
    const db = new DatabaseSync(process.argv[dbArg + 1], { readOnly: true });
    const rows = db.prepare("SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE '\\_%' ESCAPE '\\' AND name NOT LIKE 'sqlite_%' ORDER BY type DESC, name").all();
    writeFileSync(join(root, 'schema_pb_data.sql'), rows.map((r) => r.sql + ';').join('\n\n') + '\n', 'utf8');
    console.log('schema_pb_data.sql записан (' + rows.length + ' объектов)');
  } catch (e) {
    console.log('настоящий SQL из data.db не выгружен: ' + e.message);
  }
}
