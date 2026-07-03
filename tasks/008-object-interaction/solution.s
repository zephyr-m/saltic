use core

use objects.player

use objects.door

program() {
    @player = Player {}
    @door = Door {}
    @player_event = PlayerEvent {
        kind = PlayerEventKind.PICK_KEY
    }
    @next_player = react_player(player, player_event)
    @door_event = DoorEvent {
        kind = DoorEventKind.TRY_OPEN
        actor_key_state = next_player.state
    }
    @next_door = react_door(door, door_event)
    core.io.println(next_player.name)
    core.io.println(next_player.state)
    core.io.println(next_door.name)
    core.io.println(next_door.state)
    out none
}
