package ecs;

abstract Entity(Int) to Int
{
    public static final none = new Entity(-1);

    public inline function new(_id)
    {
        this = _id;
    }
}