function fail(message, field, code, text) {
  const data = {};
  data[field] = new ValidationError(code, text);
  return new BadRequestError(message, data);
}

function toDate(value) {
  return new Date(String(value).replace(" ", "T"));
}

function checkGroup(rec) {
  const start = toDate(rec.getString("starts_at"));
  const end = toDate(rec.getString("ends_at"));
  if (!(end.getTime() > start.getTime())) {
    throw fail("Группа не сохранена: проверьте поля формы.", "ends_at", "bad_range",
      "Окончание обучения должно быть позже начала.");
  }
}

function checkMedical(rec) {
  const from = toDate(rec.getString("issued_at"));
  const until = toDate(rec.getString("valid_until"));
  if (until.getTime() < from.getTime()) {
    throw fail("Справка не сохранена: проверьте поля формы.", "valid_until", "bad_range",
      "Срок действия не может быть раньше даты выдачи.");
  }
}

module.exports = { checkGroup, checkMedical };
