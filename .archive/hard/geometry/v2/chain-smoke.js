#!/usr/bin/env node

const {
  OP, edge, output, geometry, chain, compile, run, assertCausalTag, printTrace,
} = require("./runtime.js");

function stage(name, terminal = false) {
  return geometry(name, {
    inputs: { in: "value" },
    outputs: terminal ? [] : ["next"],
    nodes: {
      value: {
        counter: 0n,
        reactions: terminal ? {} : {
          inc: edge(OP.INC, output("next")),
        },
      },
    },
  });
}

const definition = chain([
  stage("FIRST"),
  stage("SECOND"),
  stage("THIRD", true),
]);
const graph = compile(definition);

const TAG = 0xC2n;
graph.fabric.send(graph.inputs.in, OP.INC, TAG);
const events = run(graph.fabric, { maxTicks: 8 });

if (events.length !== 3) throw new Error(`expected 3 interactions, got ${events.length}`);
for (let index = 0; index < 3; index += 1) {
  if (graph.cell(`stage${index}.value`).counter !== 1n) {
    throw new Error(`stage ${index} did not execute exactly once`);
  }
}
assertCausalTag(events, TAG);

printTrace(graph.fabric, events);
console.log("normal form: FIRST=1, SECOND=1, THIRD=1");
console.log("ok v2 static geometry chain");
