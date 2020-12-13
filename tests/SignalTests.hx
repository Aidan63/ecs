import ecs.ds.Signal;
import buddy.BuddySuite;

using buddy.Should;

class SignalTests extends BuddySuite
{
    public function new()
    {
        describe('Signal Tests', {
            var count = [];

            final signal = new Signal<Int>();
            final f1 = (i : Int) -> count.push('f1 $i');
            final f2 = (i : Int) -> count.push('f2 $i');
            final f3 = (i : Int) -> count.push('f3 $i');

            signal.subscribe(f1);
            signal.subscribe(f1);
            signal.subscribe(f2);
            signal.subscribe(f3);
            signal.unsubscribe(f2);

            signal.notify(1);

            it('will notify all subscribed functions', {
                count.should.containExactly([ 'f1 1', 'f3 1' ]);
            });
            it('will not add duplicate functions', {
                count.length.should.be(2);
            });
            it('will remove functions from the subscribers', {
                count.should.not.contain('f2 1');
            });
        });
    }
}