package ecs.ds;

@:generic class Signal<T>
{
    final subscribers : Array<T->Void>;

    public function new()
    {
        subscribers = [];
    }

    public function subscribe(_func : T->Void)
    {
        if (subscribers.indexOf(_func) == -1)
        {
            subscribers.push(_func);
        }
    }

    public function unsubscribe(_func : T->Void)
    {
        subscribers.remove(_func);
    }

    public function notify(_data : T)
    {
        for (func in subscribers)
        {
            func(_data);
        }
    }
}