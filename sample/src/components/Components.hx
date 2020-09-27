package components;

class Position
{
    public var x : Float;

    public var y : Float;

    public function new()
    {
        x = 0;
        y = 0;
    }
}

class Velocity
{
    public var x : Float;

    public var y : Float;

    public function new(_x, _y)
    {
        x = _x;
        y = _y;
    }
}