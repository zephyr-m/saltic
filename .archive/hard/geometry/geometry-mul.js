#!/usr/bin/env node

const {
  OP, edge, Logos, Fabric, run, assertCausalTag, printTrace,
} = require("./logos-runtime.js");

const ID = Object.freeze({ A: 0, TEMP: 1, RESULT: 2, ROUNDS: 3 });

// Copy/accumulate: A --DEC--> T --INC--> R --INC--> A
// Restore:         A(zero) --DEC--> T --DEC--> A --INC--> T
const a = new Logos(ID.A, 5n, {
  inc: edge(OP.DEC, ID.TEMP),
  dec: edge(OP.INC, ID.TEMP),
  zero: edge(OP.DEC, ID.TEMP),
}, "A");
const temp = new Logos(ID.TEMP, 0n, {
  inc: edge(OP.INC, ID.RESULT),
  dec: edge(OP.INC, ID.A),
  zero: edge(OP.DEC, ID.ROUNDS),
}, "T");
const result = new Logos(ID.RESULT, 0n, {
  inc: edge(OP.DEC, ID.A),
}, "R");
const rounds = new Logos(ID.ROUNDS, 3n, {
  dec: edge(OP.DEC, ID.A),
  zero: edge(OP.HALT, ID.RESULT),
}, "C");
const fabric = new Fabric([a, temp, result, rounds]);

const TAG = 0x53n;
fabric.send(ID.ROUNDS, OP.DEC, TAG);
const events = run(fabric, {
  maxTicks: 128,
  done: () => fabric.empty() && result.halted,
});

if (a.counter !== 5n || temp.counter !== 0n ||
    result.counter !== 15n || rounds.counter !== 0n) {
  throw new Error(`wrong normal form: A=${a.counter}, T=${temp.counter}, R=${result.counter}, C=${rounds.counter}`);
}
if (events.length !== 86) throw new Error(`expected 86 interactions, got ${events.length}`);
if (events.filter((event) =>
  event.target === ID.RESULT && event.sticker.opcode === OP.INC
).length !== 15) {
  throw new Error("RESULT did not receive exactly 15 physical increments");
}
assertCausalTag(events, TAG);

printTrace(fabric, events, { tag: false });
console.log(`normal form: A=${a.counter}, T=${temp.counter}, R=${result.counter}, C=${rounds.counter}`);
console.log("ok geometry VALUE(5) * VALUE(3) -> VALUE(15)");
