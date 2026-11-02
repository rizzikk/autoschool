sealed class Cond {
  const Cond();
}

class Eq extends Cond {
  const Eq(this.field, this.value);
  final String field;
  final Object value;
}

class Has extends Cond {
  const Has(this.field, this.value);
  final String field;
  final String value;
}

class Like extends Cond {
  const Like(this.field, this.text);
  final String field;
  final String text;
}

class Gte extends Cond {
  const Gte(this.field, this.value);
  final String field;
  final String value;
}

class Lte extends Cond {
  const Lte(this.field, this.value);
  final String field;
  final String value;
}

class And extends Cond {
  const And(this.items);
  final List<Cond> items;
}

class Or extends Cond {
  const Or(this.items);
  final List<Cond> items;
}

Cond? allOf(List<Cond> items) => switch (items.length) {
      0 => null,
      1 => items.first,
      _ => And(items),
    };
