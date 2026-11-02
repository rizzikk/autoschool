import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { COLLECTIONS, AUTO_FIELDS, USERS_ROLE_FIELD, USERS_RULES } from './schema.mjs';
import { seed } from './seed.mjs';

const BASE = process.env.PB_URL ?? 'http://127.0.0.1:8090';
const SU_EMAIL = process.env.PB_SUPERUSER_EMAIL ?? 'root@autoschool.test';
const SU_PASS = process.env.PB_SUPERUSER_PASSWORD ?? 'Autoschool123!';
const RESET = process.argv.includes('--reset');
const NO_SEED = process.argv.includes('--no-seed');
const here = dirname(fileURLToPath(import.meta.url));

let token = '';
async function api(method, path, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: token } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  if (!res.ok) {
    const err = new Error(`${method} ${path} -> ${res.status}: ${typeof data === 'string' ? data : JSON.stringify(data)}`);
    err.status = res.status;
    throw err;
  }
  return data;
}

async function main() {
  const auth = await api('POST', '/api/collections/_superusers/auth-with-password', { identity: SU_EMAIL, password: SU_PASS });
  token = auth.token;
  console.log('вход суперпользователя выполнен');

  const existing = (await api('GET', '/api/collections?perPage=200')).items;
  const byName = Object.fromEntries(existing.map((c) => [c.name, c]));

  if (RESET) {
    for (const c of [...COLLECTIONS].reverse()) {
      if (byName[c.name]) { await api('DELETE', `/api/collections/${byName[c.name].id}`); delete byName[c.name]; }
    }
    const users = await api('GET', '/api/collections/users/records?perPage=500');
    for (const u of users.items) await api('DELETE', `/api/collections/users/records/${u.id}`);
    console.log('старые коллекции и пользователи удалены');
  }

  const users = byName.users;
  const usersPatch = {};
  if (!users.fields.some((f) => f.name === 'role')) {
    usersPatch.fields = [...users.fields, USERS_ROLE_FIELD];
  }
  if (users.authToken?.duration !== 3600) {
    usersPatch.authToken = { ...(users.authToken ?? {}), duration: 3600 };
  }
  if (Object.keys(usersPatch).length > 0) {
    await api('PATCH', `/api/collections/${users.id}`, usersPatch);
    console.log('users: поле role и срок жизни токена (3600 с) настроены');
  }

  const ids = { users: users.id };
  for (const c of COLLECTIONS) {
    if (byName[c.name]) { ids[c.name] = byName[c.name].id; continue; }
    const fields = c.fields.map((f) => {
      if (f.type !== 'relation') return f;
      const { target, ...rest } = f;
      return { ...rest, collectionId: ids[target] };
    });
    const created = await api('POST', '/api/collections', {
      name: c.name, type: 'base', fields: [...fields, ...AUTO_FIELDS], indexes: c.indexes,
    });
    ids[c.name] = created.id;
    console.log('создана коллекция', c.name);
  }

  const rule = (r) => ({ listRule: r.list, viewRule: r.view, createRule: r.create, updateRule: r.update, deleteRule: r.delete });
  await api('PATCH', `/api/collections/${users.id}`, rule(USERS_RULES));
  for (const c of COLLECTIONS) await api('PATCH', `/api/collections/${ids[c.name]}`, rule(c.rules));
  console.log('правила доступа установлены');

  if (!NO_SEED) await seed(api, ids);

  const all = (await api('GET', '/api/collections?perPage=200')).items
    .filter((c) => !c.system && !c.name.startsWith('_'));
  writeFileSync(join(here, '..', 'pb_schema.json'), JSON.stringify(all, null, 2), 'utf8');
  console.log('схема сохранена в pocketbase/pb_schema.json');
}

main().catch((e) => { console.error('ОШИБКА:', e.message); process.exit(1); });
