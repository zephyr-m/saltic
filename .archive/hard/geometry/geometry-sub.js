#!/usr/bin/env node

const {
  OP, edge, Logos, Fabric, run, assertCausalTag, printTrace,
} = require("./logos-runtime.js");

const SUBTRAHEND = 0;
const RESULT = 1;

//   VALUE(2) --DEC--> VALUE(4)
//       ^                 |
//       +------DEC--------+
const subtrahend = new Logos(SUBTRAHEND, 2n, {
  dec: edge(OP.DEC, RESULT),
  zero: edge(OP.HALT, RESULT),
}, "SUBTRAHEND");
const result = new Logos(RESULT, 4n, {
  dec: edge(OP.DEC, SUBTRAHEND),
}, "RESULT");
const fabric = new Fabric([subtrahend, result]);

const TAG = 0x42n;
fabric.send(SUBTRAHEND, OP.DEC, TAG);
const events = run(fabric, {
  maxTicks: 24,
  done: () => fabric.empty() && result.halted,
});

if (subtrahend.counter !== 0n || result.counter !== 2n) {
  throw new Error(`wrong normal form: (${subtrahend.counter}, ${result.counter})`);
}
if (events.length !== 6) throw new Error(`expected 6 interactions, got ${events.length}`);
assertCausalTag(events, TAG);

printTrace(fabric, events);
console.log(`normal form: VALUE(${result.counter})`);
console.log("ok geometry VALUE(4) - VALUE(2) -> VALUE(2)");
