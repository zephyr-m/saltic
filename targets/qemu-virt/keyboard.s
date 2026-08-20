VIRTIO_EVENT_KEY = 1
KEY_LEFT_SHIFT = 42
KEY_RIGHT_SHIFT = 54

KeyEvent = Box {
    ready = no
    type = 0
    code = 0
    value = 0
}

Keyboard = Box {
    ready = no
    status = 0
    queue = VirtioQueue {}
    event = KeyEvent {}
    shift = no
}

skill keyboard_open() {
    @device = virtio_find(VIRTIO_INPUT_DEVICE)
    (core.group.count(device) < 2) { out Keyboard { status = 1 } }
    @queue = virtio_open_queue(device)
    (queue.ready == no) { out Keyboard { status = queue.status } }
    out Keyboard { ready = yes status = 4 queue = queue }
}

skill keyboard_poll(keyboard) {
    keyboard.event.ready = no
    @used = virtio_next_used(keyboard.queue)
    (used == no) { out keyboard.event }

    @offset = keyboard.queue.used_id * 8
    keyboard.event.ready = yes
    keyboard.event.type = core.mem.load16(keyboard.queue.buffers, offset)
    keyboard.event.code = core.mem.load16(keyboard.queue.buffers, offset + 2)
    keyboard.event.value = core.mem.load32(keyboard.queue.buffers, offset + 4)
    virtio_recycle(keyboard.queue, keyboard.queue.used_id)

    (keyboard.event.type == VIRTIO_EVENT_KEY) {
        (keyboard.event.code == KEY_LEFT_SHIFT) {
            keyboard.shift = yes
            (keyboard.event.value == 0) { keyboard.shift = no }
        }
        (keyboard.event.code == KEY_RIGHT_SHIFT) {
            keyboard.shift = yes
            (keyboard.event.value == 0) { keyboard.shift = no }
        }
    }
    out keyboard.event
}

skill keyboard_read(keyboard) {
    @attempt = 0
    drum (268435455) {
        @event = keyboard_poll(keyboard)
        (event.ready == yes) {
            (event.type == VIRTIO_EVENT_KEY) { out event }
        }
        attempt = attempt + 1
    }
    out error.KeyboardTimeout
}
