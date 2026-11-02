onRecordCreateRequest((e) => {
  require(`${__hooks}/lib/lessons.js`).check(e.app, e.record, e.auth);
  e.next();
}, "lessons");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/lib/lessons.js`).check(e.app, e.record, e.auth);
  e.next();
}, "lessons");

onRecordCreateRequest((e) => {
  require(`${__hooks}/lib/dates.js`).checkGroup(e.record);
  e.next();
}, "groups");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/lib/dates.js`).checkGroup(e.record);
  e.next();
}, "groups");

onRecordCreateRequest((e) => {
  require(`${__hooks}/lib/dates.js`).checkMedical(e.record);
  e.next();
}, "medical_certificates");

onRecordUpdateRequest((e) => {
  require(`${__hooks}/lib/dates.js`).checkMedical(e.record);
  e.next();
}, "medical_certificates");

routerAdd("GET", "/api/autoschool/busy", (e) => {
  const q = e.request.url.query();
  const from = q.get("from") || "";
  const to = q.get("to") || "";
  if (!from || !to) {
    throw new BadRequestError("Нужны параметры from и to.");
  }
  const found = e.app.findRecordsByFilter(
    "lessons",
    "(instructor = {:i} || car = {:c} || cadet = {:k}) && deleted = false && status != 'cancelled'" +
      " && starts_at < {:to} && ends_at > {:from}",
    "starts_at", 200, 0,
    { i: q.get("instructor") || "-", c: q.get("car") || "-", k: q.get("cadet") || "-", from: from, to: to });
  const items = found.map((r) => ({
    id: r.id,
    starts_at: r.getString("starts_at"),
    ends_at: r.getString("ends_at"),
    instructor: r.getString("instructor"),
    car: r.getString("car"),
    cadet: r.getString("cadet"),
  }));
  return e.json(200, { items: items });
}, $apis.requireAuth());
