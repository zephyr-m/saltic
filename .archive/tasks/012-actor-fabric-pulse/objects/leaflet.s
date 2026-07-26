LeafletKind = enum {
    NONE,
    PING,
    PULSE,
}

Leaflet = Box {
    kind = LeafletKind.NONE
    from = ""
    to = ""
}
