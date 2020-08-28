package ecs.macros;

import haxe.macro.Expr.ComplexType;
import haxe.ds.ReadOnlyArray;

using haxe.macro.ComplexTypeTools;

private final families = new Map<String, Int>();

private var familyIncrementer = 0;

function getFamily(_names : ReadOnlyArray<ComplexType>) {
    final buffer = new StringBuf();

    for (name in _names) {
        buffer.add(name.toString());
    }

    final concat = buffer.toString();

    trace(concat);

    if (families.exists(concat)) {
        return families.get(concat);
    } else {
        final id = familyIncrementer++;

        families.set(concat, id);

        return id;
    }
}

function getFamilyCount() {
    return familyIncrementer;
}