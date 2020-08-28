package ecs;

import ecs.Universe.ComponentManager;
import ecs.Universe.FamilyManager;

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