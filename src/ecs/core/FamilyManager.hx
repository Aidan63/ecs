package ecs.core;

import haxe.ds.Vector;
import ecs.core.ComponentManager;
import ecs.macros.FamilyCache;

class FamilyManager {
    final components : ComponentManager;

    var families : Vector<Family>;

    public function new(_components) {
        components = _components;
        
        createFamilyVector();
    }

    public function get(_index : Int) {
        return families[_index];
    }

    public function count() {
        return families.length;
    }
}