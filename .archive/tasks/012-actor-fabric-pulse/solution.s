use core

use objects.fabric

program() {
    @fabric = Fabric {}
    @ping = Leaflet {
        kind = LeafletKind.PING
        from = "outside"
        to = "A"
    }
    fabric = moment_one(fabric, ping)
    observe_moment_one(fabric, ping)
    fabric = moment_two(fabric)
    observe_moment_two(fabric)
    out none
}
