import ecs.ds.Set;
import buddy.BuddySuite;

using buddy.Should;

class SetTests extends BuddySuite
{
    public function new()
    {
        describe('Set Tests', {
            final set = new Set();
            set.add(7);
            set.add(4);
            set.add(9);
            set.add(7);
            final data = [ for (n in set) n ];

            it('will add items to the set', {
                data.should.contain(7);
                data.should.contain(4);
                data.should.contain(9);
            });

            it('will not add duplicate items', {
                data.length.should.be(3);
            });
        });
    }
}