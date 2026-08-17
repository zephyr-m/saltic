const { compose } = require("./runtime.js");

function call(fn, argument) {
  return compose("CALL", {
    instances: { argument, fn },
    wires: [
      { from: ["argument", "result"], to: ["fn", "argument"] },
    ],
    inputs: {
      in: ["argument", "in"],
    },
    outputs: {
      result: ["fn", "result"],
    },
  });
}

module.exports = { call };
