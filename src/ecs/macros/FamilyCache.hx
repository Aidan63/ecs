package ecs.macros;

import ecs.macros.SystemMacros.FamilyField;
import haxe.ds.ReadOnlyArray;

using haxe.macro.ComplexTypeTools;

private final families = new Map<String, Int>();

private var familyIncrementer = 0;

function getFamily(_fields : ReadOnlyArray<FamilyField>) {
    final buffer = new StringBuf();

    for (field in _fields) {
        buffer.add(field.type.toString());
    }

    final concat = buffer.toString();

    return if (families.exists(concat)) {
        families.get(concat);
    } else {
        final id = familyIncrementer++;

        families.set(concat, id);

        id;
    }
}

macro function createFamilyVector() {
    return macro new haxe.ds.Vector($v{ familyIncrementer });
}