package ecs;

@:autoBuild(ecs.macros.SystemMacros.familyConstruction()) class System
{
	final universe : Universe;

	public function new(_universe)
	{
		universe = _universe;
	}

	public function onAdded()
	{
		//
	}

	public function update(_dt : Float)
	{
		//
	}

	public function onRemoved()
	{
		//
	}
}