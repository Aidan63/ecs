package ecs;

abstract Entity(Int)
{
    public static final none = new Entity(-1);

    public function new(_id)
    {
        this = _id;
    }

    public function id()
    {
        return this;
    }
}