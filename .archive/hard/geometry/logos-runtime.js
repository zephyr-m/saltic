const OP = Object.freeze({ NOP: 0, INC: 1, DEC: 2, HALT: 3 });
const OP_NAME = Object.freeze(["NOP", "INC", "DEC", "HALT"]);
const MASK64 = (1n << 64n) - 1n;

function edge(opcode, target) {
  return Object.freeze({ opcode, target });
}

class Logos {
  constructor(id, counter, reactions = {}, name = String(id)) {
    this.id = id;
    this.name = name;
    this.counter = BigInt(counter);
    this.halted = false;
    this.reactions = Object.freeze({
      inc: reactions.inc ?? null,
      dec: reactions.dec ?? null,
      zero: reactions.zero ?? null,
    });
  }

  accept(sticker) {
    if (this.halted) throw new Error(`delivery to halted Logos ${this.name}`);

    let reaction = null;
    switch (sticker.opcode) {
      case OP.NOP:
        break;
      case OP.INC:
        this.counter = (this.counter + 1n) & MASK64;
        reaction = this.reactions.inc;
        break;
      case OP.DEC:
        if (this.counter === 0n) reaction = this.reactions.zero;
        else {
          this.counter -= 1n;
          reaction = this.reactions.dec;
        }
        break;
      case OP.HALT:
        this.halted = true;
        break;
      default:
        throw new Error(`invalid opcode ${sticker.opcode}`);
    }

    if (reaction === null) return null;
    return {
      source: this.id,
      target: reaction.target,
      sticker: { opcode: reaction.opcode, data: sticker.data },
    };
  }
}

class Fabric {
  constructor(cells) {
    this.cells = new Map(cells.map((cell) => [cell.id, cell]));
    this.queues = new Map(cells.map((cell) => [cell.id, []]));
    this.trace = [];
    this.tick = 0;
  }

  send(target, opcode, data, source = "host") {
    const queue = this.queues.get(target);
    if (queue === undefined) throw new Error(`unknown target ${target}`);
    queue.push({ source, target, sticker: { opcode, data } });
  }

  clock() {
    this.tick += 1;
    const accepted = [];
    const outgoing = [];

    for (const [id, cell] of this.cells) {
      const queue = this.queues.get(id);
      if (queue.length === 0 || cell.halted) continue;
      const message = queue.shift();
      const before = cell.counter;
      const reply = cell.accept(message.sticker);
      accepted.push({ ...message, before, after: cell.counter });
      if (reply !== null) outgoing.push(reply);
    }

    for (const message of outgoing) {
      this.send(message.target, message.sticker.opcode, message.sticker.data, message.source);
    }
    this.trace.push({ tick: this.tick, accepted });
    return accepted.length;
  }

  empty() {
    return [...this.queues.values()].every((queue) => queue.length === 0);
  }

  events() {
    return this.trace.flatMap((row) =>
      row.accepted.map((event) => ({ tick: row.tick, ...event })));
  }

  name(id) {
    return id === "host" ? "host" : this.cells.get(id)?.name ?? String(id);
  }
}

function run(fabric, { maxTicks, done = () => fabric.empty(), deadlock = "geometry deadlocked" }) {
  for (let tick = 0; tick < maxTicks && !done(); tick += 1) {
    if (fabric.clock() === 0 && !fabric.empty()) throw new Error(deadlock);
  }
  if (!done()) throw new Error(`geometry exceeded ${maxTicks} ticks`);
  return fabric.events();
}

function assertCausalTag(events, tag) {
  if (events.some((event) => event.sticker.data !== tag)) {
    throw new Error("causal tag was not preserved");
  }
}

function printTrace(fabric, events, { tag = true, indent = "" } = {}) {
  for (const event of events) {
    const suffix = tag ? ` tag=0x${event.sticker.data.toString(16)}` : "";
    console.log(
      `${indent}tick ${String(event.tick).padStart(2, "0")}  ` +
      `${fabric.name(event.source)}->${fabric.name(event.target)} ` +
      `${OP_NAME[event.sticker.opcode]}  ${event.before}->${event.after}${suffix}`,
    );
  }
}

module.exports = {
  OP,
  OP_NAME,
  edge,
  Logos,
  Fabric,
  run,
  assertCausalTag,
  printTrace,
};
