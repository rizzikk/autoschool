export const PASSWORD = 'Autoschool123!';

const DAY = 86400000;
const today = (() => { const n = new Date(); return Date.UTC(n.getUTCFullYear(), n.getUTCMonth(), n.getUTCDate()); })();
const iso = (ms) => new Date(ms).toISOString().replace('T', ' ');
const dayIso = (d) => iso(today + d * DAY);
const lessonStart = (d, hour) => today + d * DAY + (hour - 3) * 3600000;
const isSunday = (d) => new Date(today + d * DAY).getUTCDay() === 0;

let seedState = 20260207;
const rnd = () => { seedState |= 0; seedState = (seedState + 0x6d2b79f5) | 0; let t = Math.imul(seedState ^ (seedState >>> 15), 1 | seedState); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const pick = (a) => a[Math.floor(rnd() * a.length)];

const CATEGORIES = [
  { code: 'A', title: 'Мотоциклы', min_age: 16, theory_hours: 108, practice_hours: 18, price: 26000, description: 'Категория A: мотоциклы без ограничений по мощности.' },
  { code: 'B', title: 'Легковые автомобили', min_age: 16, theory_hours: 130, practice_hours: 56, price: 38000, description: 'Категория B: легковые автомобили до 3,5 тонн.' },
  { code: 'C', title: 'Грузовые автомобили', min_age: 18, theory_hours: 130, practice_hours: 50, price: 45000, description: 'Категория C: грузовые автомобили свыше 3,5 тонн.' },
  { code: 'D', title: 'Автобусы', min_age: 21, theory_hours: 144, practice_hours: 50, price: 48000, description: 'Категория D: автобусы более 8 пассажирских мест.' },
];

const ADMIN = { email: 'admin@autoschool.test', name: 'Петрова Анна Сергеевна' };

const INSTRUCTORS = [
  { email: 'instructor@autoschool.test', full_name: 'Козлов Сергей Викторович', phone: '+79161234501', experience_years: 12, license_no: '7712 345678', cats: ['B'] },
  { email: 'morozov@autoschool.test', full_name: 'Морозов Андрей Николаевич', phone: '+79161234502', experience_years: 8, license_no: '7712 345679', cats: ['B'] },
  { email: 'smirnova@autoschool.test', full_name: 'Смирнова Ольга Игоревна', phone: '+79161234503', experience_years: 6, license_no: '7712 345680', cats: ['B'] },
  { email: 'orlov@autoschool.test', full_name: 'Орлов Дмитрий Павлович', phone: '+79161234504', experience_years: 10, license_no: '7712 345681', cats: ['A'] },
  { email: 'lebedev@autoschool.test', full_name: 'Лебедев Виктор Степанович', phone: '+79161234505', experience_years: 20, license_no: '7712 345682', cats: ['C', 'D'] },
];

const CARS = [
  { plate: 'А123ВС77', model: 'Lada Granta', year: 2022, cat: 'B', transmission: 'manual', mileage: 48200, status: 'active', next_service: 40 },
  { plate: 'В456ЕК77', model: 'Hyundai Solaris', year: 2021, cat: 'B', transmission: 'manual', mileage: 71500, status: 'active', next_service: 25 },
  { plate: 'К789МН77', model: 'Kia Rio', year: 2023, cat: 'B', transmission: 'auto', mileage: 21300, status: 'active', next_service: 70 },
  { plate: 'Е234ОР77', model: 'Renault Logan', year: 2019, cat: 'B', transmission: 'manual', mileage: 112400, status: 'service', next_service: -5 },
  { plate: '1234АВ77', model: 'Honda CB400', year: 2020, cat: 'A', transmission: 'manual', mileage: 15800, status: 'active', next_service: 55 },
  { plate: 'Х567УС77', model: 'КамАЗ 4308', year: 2018, cat: 'C', transmission: 'manual', mileage: 98700, status: 'active', next_service: 18 },
];

const CADETS = [
  ['Иванов Алексей Сергеевич', 'B', 0, 0, 56, 'studying'],
  ['Кузнецова Мария Дмитриевна', 'B', 0, 0, 38, 'studying'],
  ['Попов Егор Андреевич', 'B', 0, 0, 24, 'studying'],
  ['Васильева Дарья Олеговна', 'B', 0, 0, 14, 'studying'],
  ['Новиков Артём Игоревич', 'B', 0, 0, 6, 'studying'],
  ['Фёдорова Полина Павловна', 'B', 0, 0, 0, 'studying'],
  ['Михайлов Кирилл Александрович', 'B', 1, 1, 58, 'graduated'],
  ['Белова Анастасия Романовна', 'B', 1, 1, 20, 'studying'],
  ['Соколов Максим Денисович', 'B', 1, 1, 9, 'studying'],
  ['Зайцева Елизавета Викторовна', 'B', 2, 2, 30, 'studying'],
  ['Лебедев Тимофей Ильич', 'B', 2, 2, 12, 'studying'],
  ['Козлова Ксения Артёмовна', 'B', 2, 2, 3, 'studying'],
  ['Григорьев Роман Евгеньевич', 'A', 3, 4, 20, 'graduated'],
  ['Дмитриева Алина Михайловна', 'A', 3, 4, 12, 'studying'],
  ['Орехов Павел Станиславович', 'A', 3, 4, 2, 'studying'],
  ['Тарасов Николай Борисович', 'C', 4, 5, 0, 'studying'],
  ['Николаева Вера Леонидовна', 'C', 4, 5, 0, 'expelled'],
  ['Егоров Владимир Константинович', 'C', 4, 5, 18, 'studying'],
].map(([full_name, cat, instr, car, quota, status], i) => ({
  n: i + 1, full_name, cat, instr, car, quota, status,
  email: i === 0 ? 'cadet@autoschool.test' : `cadet${i + 1}@autoschool.test`,
  phone: `+7926${String(1000100 + i * 137).padStart(7, '0')}`,
  birth: -Math.round(365 * (17 + rnd() * 20)),
}));

const GROUPS = [
  { name: 'Б-01 утренняя', cat: 'B', curator: 0, cadets: [1, 2, 3, 4, 5, 6] },
  { name: 'Б-02 вечерняя', cat: 'B', curator: 1, cadets: [7, 8, 9] },
  { name: 'Б-03 АКПП', cat: 'B', curator: 2, cadets: [10, 11, 12] },
  { name: 'А-01 мотоциклы', cat: 'A', curator: 3, cadets: [13, 14, 15] },
  { name: 'С-01 грузовые', cat: 'C', curator: 4, cadets: [16, 17, 18] },
];

const NOTES_GROUND = ['Трогание и остановка', 'Парковка задним ходом', 'Разворот в ограниченном пространстве', 'Эстакада', 'Змейка'];
const NOTES_CITY = ['Перекрёстки без знаков', 'Городской цикл', 'Перестроения и повороты', 'Движение по кольцу', 'Парковка во дворе', 'Ночное вождение'];

export async function seed(api, ids) {
  const create = (coll, body) => api('POST', `/api/collections/${coll}/records`, body);
  const userBody = (u, role) => ({ email: u.email, password: PASSWORD, passwordConfirm: PASSWORD, name: u.name ?? u.full_name, role, verified: true, emailVisibility: true });

  const admin = await create('users', userBody(ADMIN, 'admin'));
  const cat = {};
  for (const c of CATEGORIES) cat[c.code] = (await create('categories', { ...c, deleted: false })).id;
  console.log('категории:', Object.keys(cat).join(', '), '; администратор:', admin.email);

  const instr = [];
  for (const i of INSTRUCTORS) {
    const u = await create('users', userBody(i, 'instructor'));
    instr.push(await create('instructors', {
      user: u.id, full_name: i.full_name, phone: i.phone, experience_years: i.experience_years,
      license_no: i.license_no, categories: i.cats.map((c) => cat[c]), hired_at: dayIso(-365 * (i.experience_years > 10 ? 3 : 2)), deleted: false,
    }));
  }
  const cars = [];
  for (const c of CARS) {
    cars.push(await create('cars', {
      plate: c.plate, model: c.model, year: c.year, category: cat[c.cat], transmission: c.transmission,
      mileage: c.mileage, status: c.status, next_service: dayIso(c.next_service), deleted: false,
    }));
  }
  console.log('инструкторы:', instr.length, '; автомобили:', cars.length);

  const cadets = [];
  for (const c of CADETS) {
    const u = await create('users', userBody(c, 'cadet'));
    const rec = await create('cadets', {
      user: u.id, full_name: c.full_name, birth_date: dayIso(c.birth), phone: c.phone, category: cat[c.cat],
      status: c.status, enrolled_at: dayIso(-80), deleted: false,
    });
    cadets.push({ ...c, id: rec.id });
    if (c.n === 17) continue;
    const expired = c.n === 16;
    const soon = c.n === 12;
    await create('medical_certificates', {
      cadet: rec.id, number: `№ ${380000 + c.n * 17}`, clinic: pick(['Поликлиника № 12', 'Городская больница № 3', 'Медцентр «Здоровье»']),
      issued_at: dayIso(expired ? -400 : -100), valid_until: dayIso(expired ? -35 : soon ? 10 : 265), deleted: false,
    });
  }
  console.log('курсанты:', cadets.length);

  for (const g of GROUPS) {
    await create('groups', {
      name: g.name, category: cat[g.cat], curator: instr[g.curator].id, starts_at: dayIso(-80), ends_at: dayIso(60),
      cadets: g.cadets.map((n) => cadets[n - 1].id), deleted: false,
    });
  }

  const hours = [9, 10, 11, 12, 14, 15, 16, 17];
  const busy = new Set();
  const cadetDay = new Set();
  const planned = [];
  const place = (c, day, status, order, total) => {
    if (isSunday(day) || cadetDay.has(`${c.n}|${day}`)) return false;
    for (const h of hours) {
      const key = `${c.instr}|${day}|${h}`;
      if (busy.has(key)) continue;
      busy.add(key); cadetDay.add(`${c.n}|${day}`);
      const ground = order < total * 0.35;
      planned.push({ c, day, hour: h, status, ground, order });
      return true;
    }
    return false;
  };
  const evenDays = (list, k) => Array.from({ length: k }, (_, i) => list[Math.min(list.length - 1, Math.floor(((i + 0.5) * list.length) / k))]);
  const past = Array.from({ length: 70 }, (_, i) => -70 + i).filter((d) => !isSunday(d));
  const future = Array.from({ length: 12 }, (_, i) => 1 + i).filter((d) => !isSunday(d));

  for (const c of CADETS.map((x, i) => cadets[i])) {
    if (c.quota === 0 || c.status === 'expelled') continue;
    const wanted = evenDays(past, c.quota);
    let order = 0;
    for (const d0 of wanted) {
      for (let d = d0; d < -1; d++) { if (place(c, d, 'done', order, c.quota)) { order++; break; } }
    }
    if (c.quota >= 10) { place(c, past[3 + (c.n % 5)], 'cancelled', c.quota, c.quota); place(c, past[20 + (c.n % 7)], 'no_show', c.quota, c.quota); }
    if (c.status === 'studying') {
      const k = c.n === 1 ? 3 : 2;
      const days = c.n === 12 ? [1, 3, 5] : future;
      for (const d of evenDays(days, k)) place(c, d, 'planned', 0, 1);
    }
  }

  const stats = { done: 0, planned: 0, cancelled: 0, no_show: 0 };
  for (const p of planned) {
    const s = lessonStart(p.day, p.hour);
    const pool = p.ground ? NOTES_GROUND : NOTES_CITY;
    await create('lessons', {
      cadet: p.c.id, instructor: instr[p.c.instr].id, car: cars[p.c.car].id,
      starts_at: iso(s), ends_at: iso(s + 3600000), kind: p.ground ? 'ground' : 'city', status: p.status,
      rating: p.status === 'done' ? 3 + Math.floor(rnd() * 3) : undefined,
      notes: p.status === 'done' ? pick(pool) : p.status === 'no_show' ? 'Курсант не пришёл' : p.status === 'cancelled' ? 'Отменено по просьбе курсанта' : '',
      deleted: false,
    });
    stats[p.status]++;
  }
  console.log('занятия:', JSON.stringify(stats));

  const ex = (n, type, day, result, score, attempt, examiner = 'ГИБДД, инспектор Рябов') =>
    create('exams', { cadet: cadets[n - 1].id, type, exam_date: dayIso(day), result, score, attempt, examiner, deleted: false });
  await ex(1, 'theory', -30, 'failed', 62, 1);
  await ex(1, 'theory', -23, 'passed', 95, 2);
  await ex(1, 'ground', 6, 'scheduled', undefined, 1);
  await ex(2, 'theory', -12, 'passed', 90, 1);
  await ex(3, 'theory', -6, 'passed', 85, 1);
  await ex(7, 'theory', -50, 'passed', 92, 1);
  await ex(7, 'ground', -34, 'failed', 60, 1);
  await ex(7, 'ground', -27, 'passed', 88, 2);
  await ex(7, 'city', -15, 'passed', 91, 1);
  await ex(13, 'theory', -40, 'passed', 97, 1);
  await ex(13, 'ground', -25, 'passed', 94, 1);
  await ex(13, 'city', -14, 'passed', 90, 1);
  await ex(10, 'theory', -8, 'no_show', undefined, 1);
  console.log('экзамены: 13');

  const pay = (n, amount, day, method, purpose = 'tuition', comment = '') =>
    create('payments', { cadet: cadets[n - 1].id, amount, paid_at: dayIso(day), method, purpose, comment, deleted: false });
  await pay(1, 20000, -78, 'card', 'tuition', 'Первый взнос');
  await pay(1, 18000, -45, 'transfer', 'tuition', 'Остаток по договору');
  await pay(1, 2500, -29, 'cash', 'retake', 'Пересдача теории');
  await pay(2, 25000, -75, 'card', 'tuition', 'Частичная оплата');
  await pay(3, 19000, -70, 'cash');
  await pay(3, 19000, -40, 'card', 'tuition', 'Вторая часть');
  await pay(4, 15000, -60, 'transfer');
  await pay(5, 10000, -33, 'card');
  await pay(7, 38000, -78, 'transfer', 'tuition', 'Полная оплата');
  await pay(7, 2500, -33, 'card', 'retake', 'Пересдача площадки');
  await pay(8, 20000, -70, 'card');
  await pay(9, 12000, -50, 'cash');
  await pay(10, 30000, -66, 'card');
  await pay(11, 15000, -40, 'transfer');
  await pay(12, 8000, -20, 'cash');
  await pay(13, 26000, -79, 'card', 'tuition', 'Полная оплата');
  await pay(14, 13000, -55, 'card');
  await pay(15, 6000, -28, 'cash');
  await pay(18, 22000, -64, 'transfer');
  await pay(18, 1500, -10, 'card', 'extra_lesson', 'Дополнительное занятие');
  console.log('платежи: 20');
  console.log('учётные записи (пароль у всех', PASSWORD + '):');
  console.log('  администратор  admin@autoschool.test');
  console.log('  инструктор     instructor@autoschool.test');
  console.log('  курсант        cadet@autoschool.test');
}
