#!/usr/bin/env node

const { OP, edge, Logos, Fabric, run, printTrace } = require("./logos-runtime.js");

const ID = Object.freeze({ DUP: 0, VALUE: 1, DROP: 2 });

//   DEC -> DUP(1) --INC--> VALUE --DEC--> DUP(0) --NOP--> DROP
const dup = new Logos(ID.DUP, 1n, {
  dec: edge(OP.INC, ID.VALUE),
  zero: edge(OP.NOP, ID.DROP),
}, "DUP");
const value = new Logos(ID.VALUE, 0n, {
  inc: edge(OP.DEC, ID.DUP),
}, "VALUE");
const drop = new Logos(ID.DROP, 0n, {}, "DROP");
const fabric = new Fabric([dup, value, drop]);

const TAG = 0xD0n;
fabric.send(ID.DUP, OP.DEC, TAG);
const events = run(fabric, { maxTicks: 16 });

const expected = [
  ["host", ID.DUP, OP.DEC, 1n, 0n],
  [ID.DUP, ID.VALUE, OP.INC, 0n, 1n],
  [ID.VALUE, ID.DUP, OP.DEC, 0n, 0n],
  [ID.DUP, ID.DROP, OP.NOP, 0n, 0n],
];

if (events.length !== expected.length) {
  throw new Error(`expected ${expected.length} interactions, got ${events.length}`);
}
for (let index = 0; index < expected.length; index += 1) {
  const event = events[index];
  const [source, target, opcode, before, after] = expected[index];
  if (event.source !== source || event.target !== target ||
      event.sticker.opcode !== opcode || event.before !== before ||
      event.after !== after || event.sticker.data !== TAG) {
    throw new Error(`unexpected interaction ${index}`);
  }
}
if (dup.counter !== 0n || value.counter !== 1n || drop.counter !== 0n) {
  throw new Error("wrong DUP/APPLY/DROP normal form");
}

printTrace(fabric, events);
console.log("normal form: VALUE=1, DROP consumed, queues empty");
console.log("ok physical one-shot DUP -> APPLY + DROP geometry");
