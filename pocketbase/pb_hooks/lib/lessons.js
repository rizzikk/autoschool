const MIN_MINUTES = 30;
const MAX_MINUTES = 180;
const LEAD_MINUTES = 30;

function fail(field, code, message) {
  const data = {};
  data[field] = new ValidationError(code, message);
  return new BadRequestError("Занятие не сохранено: проверьте поля формы.", data);
}

function conflict(field, code, message) {
  const data = {};
  data[field] = new ValidationError(code, message);
  return new ApiError(409, message, data);
}

function toDate(value) {
  return new Date(String(value).replace(" ", "T"));
}

function hasOverlap(app, field, value, selfId, start, end) {
  const filter =
    field + " = {:v} && id != {:self} && deleted = false && status != 'cancelled'" +
    " && starts_at < {:end} && ends_at > {:start}";
  const found = app.findRecordsByFilter("lessons", filter, "", 1, 0, {
    v: value, self: selfId || "", start: start, end: end,
  });
  return found.length > 0;
}

function check(app, rec, auth) {
  const startStr = rec.getString("starts_at");
  const endStr = rec.getString("ends_at");
  const start = toDate(startStr);
  const end = toDate(endStr);
  const minutes = (end.getTime() - start.getTime()) / 60000;

  if (!(minutes >= MIN_MINUTES)) {
    throw fail("ends_at", "too_short", "Занятие должно длиться не меньше " + MIN_MINUTES + " минут и заканчиваться позже начала.");
  }
  if (minutes > MAX_MINUTES) {
    throw fail("ends_at", "too_long", "Занятие не может быть длиннее " + MAX_MINUTES / 60 + " часов.");
  }

  const status = rec.getString("status");
  if (rec.getBool("deleted") || status === "cancelled") return;

  if (rec.isNew() && auth && auth.collection().name === "users" && auth.getString("role") === "cadet") {
    if (start.getTime() < Date.now() + LEAD_MINUTES * 60000) {
      throw fail("starts_at", "too_soon", "Записаться можно не позднее чем за " + LEAD_MINUTES + " минут до начала.");
    }
  }

  const cadet = app.findRecordById("cadets", rec.getString("cadet"));
  const instructor = app.findRecordById("instructors", rec.getString("instructor"));
  const car = app.findRecordById("cars", rec.getString("car"));

  if (auth && auth.collection().name === "users") {
    const role = auth.getString("role");
    if (role === "cadet" && cadet.getString("user") !== auth.id) {
      throw fail("cadet", "forbidden", "Записать на занятие можно только себя.");
    }
    if (role === "instructor" && instructor.getString("user") !== auth.id) {
      throw fail("instructor", "forbidden", "Инструктор может вести только свои занятия.");
    }
  }

  const category = cadet.getString("category");
  if (car.getString("category") !== category) {
    throw fail("car", "wrong_category", "Категория автомобиля не совпадает с категорией курсанта.");
  }
  if (instructor.getStringSlice("categories").indexOf(category) < 0) {
    throw fail("instructor", "wrong_category", "Инструктор не преподаёт эту категорию.");
  }
  if (car.getString("status") !== "active") {
    throw fail("car", "car_unavailable", "Автомобиль сейчас недоступен (обслуживание или списан).");
  }

  const certs = app.findRecordsByFilter(
    "medical_certificates",
    "cadet = {:c} && deleted = false && issued_at <= {:day} && valid_until >= {:day}",
    "", 1, 0, { c: cadet.id, day: startStr });
  if (certs.length === 0) {
    throw fail("cadet", "no_medical", "У курсанта нет действующей медицинской справки на эту дату.");
  }

  if (hasOverlap(app, "instructor", instructor.id, rec.id, startStr, endStr)) {
    throw conflict("instructor", "busy", "Инструктор в это время занят другим занятием.");
  }
  if (hasOverlap(app, "car", car.id, rec.id, startStr, endStr)) {
    throw conflict("car", "busy", "Автомобиль в это время занят другим занятием.");
  }
  if (hasOverlap(app, "cadet", cadet.id, rec.id, startStr, endStr)) {
    throw conflict("cadet", "busy", "У курсанта в это время уже есть занятие.");
  }
}

module.exports = { check };
