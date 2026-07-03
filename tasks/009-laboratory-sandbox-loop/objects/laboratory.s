use core

LockState = enum {
    EMPTY,
    INSERTED,
    UNLOCKED,
}

DoorState = enum {
    CLOSED,
    OPEN,
}

InputKind = enum {
    INSERT_KEY,
    TURN_KEY,
    OPEN_DOOR,
}

Key = Box {
    code = "LAB"
}

Lock = Box {
    code = "LAB"
    state = LockState.EMPTY
}

Door = Box {
    state = DoorState.CLOSED
}

Laboratory = Box {
    key = Key {}
    lock = Lock {}
    door = Door {}
}

Input = Box {
    kind = InputKind.INSERT_KEY
}

skill insert_key(lock, key) {
    (lock.code == key.code) {
        out Lock {
            code = lock.code
            state = LockState.INSERTED
        }
    }
    out lock
}

skill turn_key(lock) {
    (lock.state == LockState.INSERTED) {
        out Lock {
            code = lock.code
            state = LockState.UNLOCKED
        }
    }
    out lock
}

skill open_door(door, lock) {
    (lock.state == LockState.UNLOCKED) {
        out Door {
            state = DoorState.OPEN
        }
    }
    out door
}

skill dispatch(lab, input) {
    (input.kind == InputKind.INSERT_KEY) {
        out Laboratory {
            key = lab.key
            lock = insert_key(lab.lock, lab.key)
            door = lab.door
        }
    }
    (input.kind == InputKind.TURN_KEY) {
        out Laboratory {
            key = lab.key
            lock = turn_key(lab.lock)
            door = lab.door
        }
    }
    (input.kind == InputKind.OPEN_DOOR) {
        out Laboratory {
            key = lab.key
            lock = lab.lock
            door = open_door(lab.door, lab.lock)
        }
    }
    out lab
}

skill render(lab) {
    core.io.println("lock: ", lab.lock.state)
    core.io.println("door: ", lab.door.state)
    out none
}
