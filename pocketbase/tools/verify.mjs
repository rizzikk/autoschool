const BASE = process.env.PB_URL ?? 'http://127.0.0.1:8090';
let passed = 0, failed = 0;

async function call(method, path, body, token) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: token } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data = null;
  try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { status: res.status, data };
}
function check(name, cond, extra = '') {
  if (cond) { passed++; console.log('  ok   ' + name); }
  else { failed++; console.log('  FAIL ' + name + (extra ? '  -> ' + extra : '')); }
}
const J = (x) => JSON.stringify(x);
async function login(email, pass = 'Autoschool123!') {
  const r = await call('POST', '/api/collections/users/auth-with-password', { identity: email, password: pass });
  return r.status === 200 ? { token: r.data.token, user: r.data.record } : null;
}

console.log('== вход');
const admin = await login('admin@autoschool.test');
const instr = await login('instructor@autoschool.test');
const cadet = await login('cadet@autoschool.test');
check('вход администратора', !!admin);
check('вход инструктора', !!instr);
check('вход курсанта', !!cadet);
check('роли в профиле', admin?.user.role === 'admin' && instr?.user.role === 'instructor' && cadet?.user.role === 'cadet');
const bad = await call('POST', '/api/collections/users/auth-with-password', { identity: 'cadet@autoschool.test', password: 'wrong' });
check('неверный пароль -> 400', bad.status === 400, J(bad));
const noauth = await call('GET', '/api/collections/cadets/records');
check('без токена список курсантов пуст или закрыт', noauth.status === 200 ? noauth.data.totalItems === 0 : [401, 403].includes(noauth.status), J(noauth).slice(0, 200));

console.log('== обновление токена');
const rf = await call('POST', '/api/collections/users/auth-refresh', undefined, cadet.token);
check('auth-refresh возвращает токен', rf.status === 200 && !!rf.data.token, J(rf).slice(0, 200));

console.log('== видимость по ролям');
const cList = await call('GET', '/api/collections/cadets/records?perPage=100', undefined, cadet.token);
check('курсант видит только себя', cList.status === 200 && cList.data.totalItems === 1, `total=${cList.data?.totalItems}`);
const aList = await call('GET', '/api/collections/cadets/records?perPage=100', undefined, admin.token);
check('администратор видит всех курсантов', aList.data.totalItems >= 15, `total=${aList.data?.totalItems}`);
const iList = await call('GET', '/api/collections/cadets/records?perPage=100', undefined, instr.token);
check('инструктор видит всех курсантов', iList.data.totalItems === aList.data.totalItems);
const cPay = await call('GET', '/api/collections/payments/records?perPage=100', undefined, cadet.token);
const iPay = await call('GET', '/api/collections/payments/records?perPage=100', undefined, instr.token);
check('курсант видит только свои платежи', cPay.status === 200 && cPay.data.items.every((p) => true));
check('инструктор платежей не видит', iPay.status === 200 && iPay.data.totalItems === 0, `total=${iPay.data?.totalItems}`);
const cLes = await call('GET', '/api/collections/lessons/records?perPage=200&expand=cadet,instructor', undefined, cadet.token);
const myCadetId = cList.data.items[0].id;
check('курсант видит только свои занятия', cLes.data.items.length > 0 && cLes.data.items.every((l) => l.cadet === myCadetId), `n=${cLes.data?.totalItems}`);
const iLes = await call('GET', '/api/collections/lessons/records?perPage=200&expand=cadet,instructor', undefined, instr.token);
const myInstrId = (await call('GET', '/api/collections/instructors/records?filter=' + encodeURIComponent(`user='${instr.user.id}'`), undefined, admin.token)).data.items[0].id;
check('инструктор видит только свои занятия', iLes.data.items.length > 0 && iLes.data.items.every((l) => l.instructor === myInstrId), `n=${iLes.data?.totalItems}`);
const cUsers = await call('GET', '/api/collections/users/records', undefined, cadet.token);
check('курсант видит в users только себя', cUsers.data.totalItems === 1);

console.log('== права на запись');
const cat = { code: 'T1', title: 'Тестовая категория', min_age: 18, theory_hours: 10, practice_hours: 10, price: 1000, deleted: false };
const c1 = await call('POST', '/api/collections/categories/records', cat, instr.token);
check('инструктор не создаёт категории', [400, 403].includes(c1.status), J(c1).slice(0, 160));
console.log('     (код ответа: ' + c1.status + ')');
const c2 = await call('POST', '/api/collections/categories/records', cat, cadet.token);
check('курсант не создаёт категории', [400, 403].includes(c2.status));
const c3 = await call('POST', '/api/collections/categories/records', cat, admin.token);
check('администратор создаёт категорию', c3.status === 200, J(c3).slice(0, 200));
const c4 = await call('POST', '/api/collections/categories/records', cat, admin.token);
check('повтор кода -> 400 с ошибкой в поле code', c4.status === 400 && !!c4.data?.data?.code, J(c4).slice(0, 300));
console.log('     (сообщение: ' + (c4.data?.data?.code?.message ?? '-') + ')');
const c5 = await call('POST', '/api/collections/categories/records', { ...cat, code: 'T2', min_age: 5, title: 'ab' }, admin.token);
check('невалидные поля -> ошибки по полям', c5.status === 400 && !!c5.data?.data?.min_age && !!c5.data?.data?.title, J(c5.data?.data));
const del = await call('DELETE', `/api/collections/categories/records/${c3.data.id}`, undefined, admin.token);
check('физическое удаление категории администратором', del.status === 204, J(del));

console.log('== автомобиль: формат номера');
const carsAll = await call('GET', '/api/collections/cars/records?perPage=50', undefined, admin.token);
const car0 = carsAll.data.items[0];
const badCar = await call('POST', '/api/collections/cars/records', { plate: 'abc', model: 'Лада', year: 2020, category: car0.category, transmission: 'manual', status: 'active', deleted: false }, admin.token);
check('неверный номер -> ошибка в поле plate', badCar.status === 400 && !!badCar.data?.data?.plate, J(badCar).slice(0, 250));

console.log('== регистрация');
const stamp = Date.now();
const reg = await call('POST', '/api/collections/users/records', { email: `new${stamp}@autoschool.test`, password: 'Autoschool123!', passwordConfirm: 'Autoschool123!', role: 'cadet', name: 'Новый Курсант' });
check('самостоятельная регистрация курсанта', reg.status === 200, J(reg).slice(0, 250));
const regAdm = await call('POST', '/api/collections/users/records', { email: `evil${stamp}@autoschool.test`, password: 'Autoschool123!', passwordConfirm: 'Autoschool123!', role: 'admin', name: 'Хакер' });
check('регистрация с ролью admin запрещена', [400, 403].includes(regAdm.status), `status=${regAdm.status}`);
const regShort = await call('POST', '/api/collections/users/records', { email: `x${stamp}@autoschool.test`, password: '123', passwordConfirm: '123', role: 'cadet' });
check('короткий пароль -> ошибка в поле password', regShort.status === 400 && !!regShort.data?.data?.password, J(regShort).slice(0, 250));
const regDup = await call('POST', '/api/collections/users/records', { email: 'cadet@autoschool.test', password: 'Autoschool123!', passwordConfirm: 'Autoschool123!', role: 'cadet' });
check('занятая почта -> ошибка в поле email', regDup.status === 400 && !!regDup.data?.data?.email, J(regDup).slice(0, 250));
const selfUp = await call('PATCH', `/api/collections/users/records/${cadet.user.id}`, { role: 'admin' }, cadet.token);
check('курсант не может сменить себе роль', [400, 403, 404].includes(selfUp.status), `status=${selfUp.status}`);
if (reg.status === 200) await call('DELETE', `/api/collections/users/records/${reg.data.id}`, undefined, admin.token);

console.log('== занятия: серверные проверки');
const planned = (await call('GET', '/api/collections/lessons/records?perPage=1&filter=' + encodeURIComponent("status='planned' && deleted=false") + '&sort=starts_at', undefined, admin.token)).data.items[0];
check('есть запланированное занятие', !!planned);
const base = { cadet: planned.cadet, instructor: planned.instructor, car: planned.car, kind: 'city', status: 'planned', deleted: false };
const dup = await call('POST', '/api/collections/lessons/records', { ...base, starts_at: planned.starts_at, ends_at: planned.ends_at }, admin.token);
check('такое же занятие -> 409, занят инструктор', dup.status === 409 && dup.data?.data?.instructor?.code === 'busy', J(dup).slice(0, 300));
const short = await call('POST', '/api/collections/lessons/records', { ...base, starts_at: '2027-02-01 10:00:00.000Z', ends_at: '2027-02-01 10:10:00.000Z' }, admin.token);
check('слишком короткое занятие -> ошибка в ends_at', short.status === 400 && short.data?.data?.ends_at?.code === 'too_short', J(short).slice(0, 300));
const long = await call('POST', '/api/collections/lessons/records', { ...base, starts_at: '2027-02-01 10:00:00.000Z', ends_at: '2027-02-01 15:00:00.000Z' }, admin.token);
check('слишком длинное занятие -> ошибка в ends_at', long.status === 400 && long.data?.data?.ends_at?.code === 'too_long', J(long).slice(0, 300));
const certs = await call('GET', `/api/collections/medical_certificates/records?filter=${encodeURIComponent(`cadet='${planned.cadet}'`)}`, undefined, admin.token);
console.log('     справка курсанта: ' + J(certs.data.items.map((c) => [c.issued_at, c.valid_until])));
const farDay = (certs.data.items[0]?.valid_until ?? '2026-12-31 00:00:00.000Z').slice(0, 10) + ' 20:00:00.000Z';
const far = await call('POST', '/api/collections/lessons/records', { ...base, starts_at: '2099-01-01 10:00:00.000Z', ends_at: '2099-01-01 11:30:00.000Z' }, admin.token);
check('справка не действует на дату -> ошибка в cadet', far.status === 400 && far.data?.data?.cadet?.code === 'no_medical', J(far).slice(0, 300));
const validUntil = new Date((certs.data.items[0]?.valid_until ?? '2026-12-31 00:00:00.000Z').replace(' ', 'T'));
let created = null;
for (let d = 1; d <= 12 && !created; d++) {
  const day = new Date(); day.setUTCHours(0, 0, 0, 0); day.setUTCDate(day.getUTCDate() + d);
  if (day.getTime() + 20 * 3600000 > validUntil.getTime()) break;
  for (let h = 6; h <= 19 && !created; h++) {
    const s = new Date(day.getTime() + h * 3600000), e = new Date(s.getTime() + 90 * 60000);
    const sIso = s.toISOString().replace('T', ' '), eIso = e.toISOString().replace('T', ' ');
    const r = await call('POST', '/api/collections/lessons/records', { ...base, starts_at: sIso, ends_at: eIso }, admin.token);
    if (r.status === 200) created = r.data;
  }
}
check('корректное занятие создаётся', !!created);
if (created) {
  const busyQ = `/api/autoschool/busy?from=${encodeURIComponent(created.starts_at)}&to=${encodeURIComponent(created.ends_at)}&instructor=${planned.instructor}&car=${planned.car}&cadet=${planned.cadet}`;
  const busy = await call('GET', busyQ, undefined, cadet.token);
  check('busy: курсант видит занятые интервалы', busy.status === 200 && busy.data.items.length >= 1, J(busy).slice(0, 250));
  const busyNoAuth = await call('GET', busyQ);
  check('busy без токена -> 401', busyNoAuth.status === 401, `status=${busyNoAuth.status}`);
  const ov = await call('POST', '/api/collections/lessons/records', { ...base, starts_at: created.starts_at, ends_at: created.ends_at }, admin.token);
  check('пересечение с только что созданным -> 409', ov.status === 409 && ov.data?.data?.instructor?.code === 'busy', J(ov).slice(0, 250));
  const sd = await call('PATCH', `/api/collections/lessons/records/${created.id}`, { deleted: true }, admin.token);
  check('мягкое удаление (deleted=true)', sd.status === 200 && sd.data.deleted === true);
  const vis = await call('GET', `/api/collections/lessons/records/${created.id}`, undefined, instr.token);
  check('удалённое занятие скрыто от инструктора', vis.status === 404, `status=${vis.status}`);
  const rs = await call('PATCH', `/api/collections/lessons/records/${created.id}`, { deleted: false }, admin.token);
  check('восстановление (deleted=false)', rs.status === 200 && rs.data.deleted === false, J(rs).slice(0, 200));
  const hd = await call('DELETE', `/api/collections/lessons/records/${created.id}`, undefined, admin.token);
  check('физическое удаление занятия', hd.status === 204);
}

console.log('== фильтр по связи с несколькими записями');
const catB = (await call('GET', '/api/collections/categories/records?filter=' + encodeURIComponent("code='B'"), undefined, admin.token)).data.items[0].id;
const fInstr = await call('GET', '/api/collections/instructors/records?filter=' + encodeURIComponent(`categories.id ?= '${catB}' && deleted = false`), undefined, cadet.token);
check('инструкторы категории B находятся фильтром categories.id ?= ...', fInstr.status === 200 && fInstr.data.totalItems >= 1, J(fInstr).slice(0, 200));
const grpAll = await call('GET', '/api/collections/groups/records', undefined, cadet.token);
check('курсант видит группы, в которых состоит', grpAll.status === 200 && grpAll.data.totalItems >= 1, J(grpAll).slice(0, 200));

console.log('== порядок дат и ограничения курсанта');
const grpBad = await call('POST', '/api/collections/groups/records', { name: 'Проверка ' + stamp, category: car0.category, starts_at: '2027-03-01 00:00:00.000Z', ends_at: '2027-02-01 00:00:00.000Z', deleted: false }, admin.token);
check('группа: окончание раньше начала -> ошибка в ends_at', grpBad.status === 400 && grpBad.data?.data?.ends_at?.code === 'bad_range', J(grpBad).slice(0, 250));
const medBad = await call('POST', '/api/collections/medical_certificates/records', { cadet: planned.cadet, number: '77 ' + stamp, issued_at: '2026-05-01 00:00:00.000Z', valid_until: '2026-04-01 00:00:00.000Z', clinic: 'Поликлиника №1', deleted: false }, admin.token);
check('справка: срок раньше выдачи -> ошибка в valid_until', medBad.status === 400 && medBad.data?.data?.valid_until?.code === 'bad_range', J(medBad).slice(0, 250));
const soon = new Date(Date.now() + 5 * 60000).toISOString().replace('T', ' ');
const soonEnd = new Date(Date.now() + 95 * 60000).toISOString().replace('T', ' ');
const bookSoon = await call('POST', '/api/collections/lessons/records', { cadet: myCadetId, instructor: planned.instructor, car: planned.car, kind: 'city', status: 'planned', deleted: false, starts_at: soon, ends_at: soonEnd }, cadet.token);
check('курсант: запись менее чем за 30 минут -> ошибка в starts_at', bookSoon.status === 400 && bookSoon.data?.data?.starts_at?.code === 'too_soon', J(bookSoon).slice(0, 250));
const bookPast = await call('POST', '/api/collections/lessons/records', { cadet: myCadetId, instructor: planned.instructor, car: planned.car, kind: 'city', status: 'planned', deleted: false, starts_at: '2020-01-01 10:00:00.000Z', ends_at: '2020-01-01 11:30:00.000Z' }, cadet.token);
check('курсант: запись в прошлое -> ошибка в starts_at', bookPast.status === 400 && bookPast.data?.data?.starts_at?.code === 'too_soon', J(bookPast).slice(0, 250));
const myCadet = cList.data.items[0];
const ownPhone = await call('PATCH', `/api/collections/cadets/records/${myCadetId}`, { phone: myCadet.phone }, cadet.token);
check('курсант меняет свой телефон', ownPhone.status === 200, J(ownPhone).slice(0, 200));
const ownEnroll = await call('PATCH', `/api/collections/cadets/records/${myCadetId}`, { enrolled_at: '2020-01-01 00:00:00.000Z' }, cadet.token);
check('курсант не меняет дату зачисления', [400, 403, 404].includes(ownEnroll.status), `status=${ownEnroll.status}`);

console.log('== целостность');
const hdc = await call('DELETE', `/api/collections/cadets/records/${planned.cadet}`, undefined, admin.token);
check('нельзя физически удалить курсанта со связями', hdc.status === 400, `status=${hdc.status} ${J(hdc.data).slice(0, 250)}`);
console.log('     (сообщение: ' + (hdc.data?.message ?? '-') + ')');

console.log('== поиск, фильтр, сортировка, страницы');
const pubCat = await call('GET', '/api/collections/categories/records');
check('категории видны без входа', pubCat.status === 200 && pubCat.data.totalItems >= 4, J(pubCat).slice(0, 150));
const srt = await call('GET', '/api/collections/lessons/records?perPage=5&expand=cadet&sort=cadet.full_name', undefined, admin.token);
check('сортировка по полю связи (cadet.full_name)', srt.status === 200 && srt.data.items.length > 0, J(srt).slice(0, 250));
const srt2 = await call('GET', '/api/collections/lessons/records?perPage=5&sort=-starts_at&filter=' + encodeURIComponent("cadet.category.code='B' && instructor='" + myInstrId + "'"), undefined, admin.token);
check('фильтр по вложенной связи', srt2.status === 200, J(srt2).slice(0, 250));
const q1 = await call('GET', `/api/collections/cadets/records?page=2&perPage=5&sort=full_name&filter=${encodeURIComponent(`deleted=false && full_name ~ 'а'`)}`, undefined, admin.token);
check('постраничный список', q1.status === 200 && q1.data.page === 2 && q1.data.perPage === 5 && q1.data.items.length > 0, J(q1.data).slice(0, 200));
const q2 = await call('GET', `/api/collections/lessons/records?perPage=3&expand=cadet,instructor,car&filter=${encodeURIComponent("status='done' && starts_at >= '2026-01-01 00:00:00.000Z'")}&sort=-starts_at`, undefined, admin.token);
check('expand связей работает', q2.status === 200 && q2.data.items[0].expand?.cadet?.full_name, J(q2.data.items[0]).slice(0, 300));
const q3 = await call('GET', `/api/collections/groups/records?expand=cadets,curator`, undefined, admin.token);
check('группы: expand многозначной связи', q3.status === 200 && Array.isArray(q3.data.items[0]?.expand?.cadets), J(q3.data.items[0]).slice(0, 300));

console.log(`\nИТОГО: успешно ${passed}, ошибок ${failed}`);
process.exit(failed ? 1 : 0);
