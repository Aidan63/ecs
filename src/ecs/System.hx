package ecs;

import ecs.core.ComponentManager;
import ecs.core.FamilyManager;

@:autoBuild(ecs.macros.SystemMacros.familyConstruction()) class System {
    var families : FamilyManager;
	var components : ComponentManager;

	public function new(_families, _components) {
		families   = _families;
		components = _components;
	}

	public function onAdded() {
		//
	}

	public function onRemoved() {
		//
	}
}