#!/usr/bin/env node

const OP = Object.freeze({ NOP: 0, INC: 1, DEC: 2, HALT: 3 });
const OP_NAME = Object.freeze(["NOP", "INC", "DEC", "HALT"]);
const MASK64 = (1n << 64n) - 1n;

function reaction(opcode, target) {
  return Object.freeze({ opcode, target });
}

class Logos {
  constructor(id, counter, reactions = {}) {
    this.id = id;
    this.counter = BigInt(counter);
    this.halted = false;
    this.reactions = Object.freeze({
      inc: reactions.inc ?? null,
      dec: reactions.dec ?? null,
      zero: reactions.zero ?? null,
    });
  }

  accept(sticker) {
    if (this.halted) throw new Error(`sticker delivered to halted Logos ${this.id}`);

    let selected = null;
    switch (sticker.opcode) {
      case OP.NOP:
        break;
      case OP.INC:
        this.counter = (this.counter + 1n) & MASK64;
        selected = this.reactions.inc;
        break;
      case OP.DEC:
        if (this.counter === 0n) {
          selected = this.reactions.zero;
        } else {
          this.counter -= 1n;
          selected = this.reactions.dec;
        }
        break;
      case OP.HALT:
        this.halted = true;
        break;
      default:
        throw new Error(`invalid opcode ${sticker.opcode}`);
    }

    if (selected === null) return null;
    return {
      source: this.id,
      target: selected.target,
      sticker: { opcode: selected.opcode, data: sticker.data },
    };
  }
}

// Fabric deliberately knows nothing about counters, zero branches or programs.
class Fabric {
  constructor(cells) {
    this.cells = new Map(cells.map((cell) => [cell.id, cell]));
    this.queues = new Map(cells.map((cell) => [cell.id, []]));
    this.tick = 0;
    this.trace = [];
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

    // Every Logos may accept at most one sticker. All accepted stickers belong
    // to the same logical instant; their replies become visible next tick.
    for (const [id, cell] of this.cells) {
      const queue = this.queues.get(id);
      if (queue.length === 0 || cell.halted) continue;
      const message = queue.shift();
      const before = cell.counter;
      const reply = cell.accept(message.sticker);
      accepted.push({
        source: message.source,
        target: id,
        opcode: message.sticker.opcode,
        data: message.sticker.data,
        before,
        after: cell.counter,
      });
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
}

// A program graph is only counters plus labelled reaction edges. The same
// topology transfers one unit at a time; the edge opcode determines whether
// transferred mass is accumulated or cancelled.
function transferGraph(firstId, secondId, sourceValue, resultValue, transferOpcode) {
  const source = new Logos(firstId, sourceValue, {
    dec: reaction(transferOpcode, secondId),
    zero: reaction(OP.HALT, secondId),
  });
  const result = new Logos(secondId, resultValue, {
    inc: reaction(OP.DEC, firstId),
    dec: reaction(OP.DEC, firstId),
    zero: reaction(OP.HALT, firstId),
  });
  return { source, result };
}

const graphA = transferGraph(0, 1, 5n, 3n, OP.INC);
const graphB = transferGraph(2, 3, 2n, 4n, OP.DEC);
const fabric = new Fabric([
  graphA.source,
  graphA.result,
  graphB.source,
  graphB.result,
]);

// Two independent initial impulses enter the same fabric simultaneously.
fabric.send(graphA.source.id, OP.DEC, 0xA1n);
fabric.send(graphB.source.id, OP.DEC, 0xB2n);

for (let limit = 0; limit < 100 && (!fabric.empty() || !graphA.result.halted || !graphB.result.halted); limit += 1) {
  if (fabric.clock() === 0 && !fabric.empty()) throw new Error("mass deadlocked");
}

for (const row of fabric.trace) {
  if (row.accepted.length === 0) continue;
  const events = row.accepted.map((event) => {
    const route = `${event.source}->${event.target}`;
    const change = `${event.before}->${event.after}`;
    return `${route} ${OP_NAME[event.opcode]} ${change} data=0x${event.data.toString(16)}`;
  });
  console.log(`tick ${String(row.tick).padStart(2, "0")}  ${events.join(" | ")}`);
}

if (!fabric.empty()) throw new Error("messages remain in fabric");
if (!graphA.result.halted || !graphB.result.halted) throw new Error("a graph did not halt");
if (graphA.source.counter !== 0n || graphA.result.counter !== 8n) {
  throw new Error("graph A has the wrong normal form");
}
if (graphB.source.counter !== 0n || graphB.result.counter !== 2n) {
  throw new Error("graph B has the wrong normal form");
}

const dataA = fabric.trace.flatMap((row) => row.accepted).filter((event) => event.data === 0xA1n);
const dataB = fabric.trace.flatMap((row) => row.accepted).filter((event) => event.data === 0xB2n);
if (dataA.some((event) => ![0, 1].includes(event.target))) throw new Error("graph A leaked into B");
if (dataB.some((event) => ![2, 3].includes(event.target))) throw new Error("graph B leaked into A");

console.log(`normal forms: A=${graphA.result.counter}, B=${graphB.result.counter}`);
console.log(`interactions: A=${dataA.length}, B=${dataB.length}`);
