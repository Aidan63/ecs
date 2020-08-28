package ecs;

import ecs.core.ComponentManager;
import ecs.core.FamilyManager;

@:autoBuild(ecs.macros.SystemMacros.familyConstruction()) class System {
    var families : FamilyManager;
	var components : ComponentManager;

	public function onAdded() {
		//
	}

	public function onRemoved() {
		//
	}
}