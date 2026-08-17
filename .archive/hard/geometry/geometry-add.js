#!/usr/bin/env node

const {
  OP, edge, Logos, Fabric, run, assertCausalTag, printTrace,
} = require("./logos-runtime.js");

const SOURCE = 0;
const RESULT = 1;

//   VALUE(5) --INC--> VALUE(3)
//       ^                 |
//       +------DEC--------+
const source = new Logos(SOURCE, 5n, {
  dec: edge(OP.INC, RESULT),
  zero: edge(OP.HALT, RESULT),
}, "SOURCE");
const result = new Logos(RESULT, 3n, {
  inc: edge(OP.DEC, SOURCE),
}, "RESULT");
const fabric = new Fabric([source, result]);

const TAG = 0x53n;
fabric.send(SOURCE, OP.DEC, TAG);
const events = run(fabric, {
  maxTicks: 32,
  done: () => fabric.empty() && result.halted,
});

if (source.counter !== 0n || result.counter !== 8n) {
  throw new Error(`wrong normal form: (${source.counter}, ${result.counter})`);
}
if (events.length !== 12) throw new Error(`expected 12 interactions, got ${events.length}`);
assertCausalTag(events, TAG);

printTrace(fabric, events);
console.log(`normal form: VALUE(${source.counter}), VALUE(${result.counter})`);
console.log("ok geometry VALUE(5) + VALUE(3) -> VALUE(8)");
