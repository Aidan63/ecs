package ecs.core;

import haxe.ds.Vector;
import ecs.core.ComponentManager;
import ecs.macros.FamilyCache;

class FamilyManager {
    final components : ComponentManager;

    var families : Vector<Family>;

    public function new(_components) {
        components = _components;
        families   = createVector();
    }

    public function get(_index : Int) {
        return families[_index];
    }

    static macro function createVector() {
        final count = getFamilyCount();

        return macro new haxe.ds.Vector($v{ count });
    }
}