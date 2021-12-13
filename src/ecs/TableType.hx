package ecs;

abstract TableType(String) from String to String
{
	function new(value)
    {
        this = value;
	}
	
	@:from static function fromClass(input:Class<Dynamic>)
    {
        return new TableType(Type.getClassName(input));
	}
}