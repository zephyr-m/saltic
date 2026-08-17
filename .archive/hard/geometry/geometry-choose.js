#!/usr/bin/env node

const { OP, edge, Logos, Fabric, run, printTrace } = require("./logos-runtime.js");

const ID = Object.freeze({ CONDITION: 0, ZERO: 1, NONZERO: 2 });

function choose(input) {
  const condition = new Logos(ID.CONDITION, input, {
    zero: edge(OP.INC, ID.ZERO),
    dec: edge(OP.INC, ID.NONZERO),
  }, "CONDITION");
  const zero = new Logos(ID.ZERO, 0n, {}, "ZERO");
  const nonzero = new Logos(ID.NONZERO, 0n, {}, "NONZERO");
  const fabric = new Fabric([condition, zero, nonzero]);

  fabric.send(ID.CONDITION, OP.DEC, input === 0n ? 0xA0n : 0xB1n);
  const events = run(fabric, { maxTicks: 4 });

  if (input === 0n && (zero.counter !== 1n || nonzero.counter !== 0n)) {
    throw new Error("ZERO selected the wrong branch");
  }
  if (input !== 0n && (zero.counter !== 0n || nonzero.counter !== 1n)) {
    throw new Error("NONZERO selected the wrong branch");
  }
  return { input, fabric, events, zero, nonzero };
}

for (const result of [choose(0n), choose(1n)]) {
  console.log(`CONDITION=${result.input}`);
  printTrace(result.fabric, result.events, { tag: false, indent: "  " });
  console.log(`  branches: ZERO=${result.zero.counter}, NONZERO=${result.nonzero.counter}`);
}

console.log("ok physical CHOOSE: ZERO -> A, NONZERO -> B");
