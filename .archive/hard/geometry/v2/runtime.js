const {
  OP,
  edge,
  Logos,
  Fabric,
  run,
  assertCausalTag,
  printTrace,
} = require("../logos-runtime.js");

function local(node) {
  return Object.freeze({ kind: "local", node });
}

function output(port) {
  return Object.freeze({ kind: "output", port });
}

function geometry(name, { nodes, inputs = {}, outputs = [] }) {
  if (!name || !nodes) throw new Error("geometry requires name and nodes");
  return Object.freeze({
    name,
    nodes: Object.freeze(nodes),
    inputs: Object.freeze(inputs),
    outputs: new Set(outputs),
  });
}

function compose(name, { instances, wires = [], inputs = {}, outputs = {} }) {
  const entries = Object.entries(instances);
  if (!entries.length) throw new Error("composition requires instances");

  const wireTargets = new Map();
  for (const wire of wires) {
    const [fromInstance, fromPort] = wire.from;
    const [toInstance, toPort] = wire.to;
    const source = instances[fromInstance];
    const target = instances[toInstance];
    if (!source?.outputs.has(fromPort)) {
      throw new Error(`${fromInstance} has no output ${fromPort}`);
    }
    const targetNode = target?.inputs[toPort];
    if (targetNode === undefined) {
      throw new Error(`${toInstance} has no input ${toPort}`);
    }
    const key = `${fromInstance}:${fromPort}`;
    if (wireTargets.has(key)) throw new Error(`output ${key} is connected twice`);
    wireTargets.set(key, `${toInstance}.${targetNode}`);
  }

  const exposedOutputs = new Map();
  for (const [externalPort, endpoint] of Object.entries(outputs)) {
    const [instanceName, port] = endpoint;
    if (!instances[instanceName]?.outputs.has(port)) {
      throw new Error(`${instanceName} has no output ${port}`);
    }
    const key = `${instanceName}:${port}`;
    if (wireTargets.has(key)) throw new Error(`connected output ${key} cannot also be exposed`);
    exposedOutputs.set(key, externalPort);
  }

  function mapTarget(instanceName, target) {
    if (!target || typeof target !== "object") {
      throw new Error("reaction target must be local() or output()");
    }
    if (target.kind === "local") return local(`${instanceName}.${target.node}`);
    if (target.kind !== "output") throw new Error(`unknown target kind ${target.kind}`);

    const key = `${instanceName}:${target.port}`;
    const wiredNode = wireTargets.get(key);
    if (wiredNode !== undefined) return local(wiredNode);
    const externalPort = exposedOutputs.get(key);
    if (externalPort !== undefined) return output(externalPort);
    throw new Error(`output ${key} is neither connected nor exposed`);
  }

  function mapReaction(instanceName, reaction) {
    if (reaction == null) return null;
    return edge(reaction.opcode, mapTarget(instanceName, reaction.target));
  }

  const nodes = {};
  for (const [instanceName, definition] of entries) {
    for (const [nodeName, spec] of Object.entries(definition.nodes)) {
      nodes[`${instanceName}.${nodeName}`] = {
        counter: spec.counter,
        reactions: {
          inc: mapReaction(instanceName, spec.reactions?.inc),
          dec: mapReaction(instanceName, spec.reactions?.dec),
          zero: mapReaction(instanceName, spec.reactions?.zero),
        },
      };
    }
  }

  const mappedInputs = {};
  for (const [externalPort, endpoint] of Object.entries(inputs)) {
    const [instanceName, port] = endpoint;
    const nodeName = instances[instanceName]?.inputs[port];
    if (nodeName === undefined) throw new Error(`${instanceName} has no input ${port}`);
    mappedInputs[externalPort] = `${instanceName}.${nodeName}`;
  }

  return geometry(name, {
    nodes,
    inputs: mappedInputs,
    outputs: Object.keys(outputs),
  });
}

function chain(definitions) {
  if (!Array.isArray(definitions) || definitions.length === 0) {
    throw new Error("chain requires at least one geometry");
  }
  if (definitions.length === 1) return definitions[0];

  const instances = {};
  const wires = [];
  definitions.forEach((definition, index) => {
    instances[`stage${index}`] = definition;
    if (index > 0) {
      wires.push({
        from: [`stage${index - 1}`, "next"],
        to: [`stage${index}`, "in"],
      });
    }
  });

  const last = definitions.length - 1;
  const exposedOutputs = definitions[last].outputs.has("next")
    ? { next: [`stage${last}`, "next"] }
    : {};

  return compose("CHAIN", {
    instances,
    wires,
    inputs: { in: ["stage0", "in"] },
    outputs: exposedOutputs,
  });
}

function compile(definition) {
  const ids = new Map();
  let nextId = 0;
  for (const nodeName of Object.keys(definition.nodes)) ids.set(nodeName, nextId++);

  const outputIds = new Map();
  for (const port of definition.outputs) outputIds.set(port, nextId++);

  function resolveTarget(target) {
    if (target.kind === "local") {
      const id = ids.get(target.node);
      if (id === undefined) throw new Error(`unknown local node ${target.node}`);
      return id;
    }
    if (target.kind === "output") {
      const id = outputIds.get(target.port);
      if (id === undefined) throw new Error(`unknown output port ${target.port}`);
      return id;
    }
    throw new Error(`unknown target kind ${target.kind}`);
  }

  function resolveReaction(reaction) {
    return reaction == null ? null : edge(reaction.opcode, resolveTarget(reaction.target));
  }

  const cells = [];
  const cellsByName = new Map();
  for (const [nodeName, spec] of Object.entries(definition.nodes)) {
    const cell = new Logos(ids.get(nodeName), spec.counter, {
      inc: resolveReaction(spec.reactions?.inc),
      dec: resolveReaction(spec.reactions?.dec),
      zero: resolveReaction(spec.reactions?.zero),
    }, nodeName);
    cells.push(cell);
    cellsByName.set(nodeName, cell);
  }

  for (const [port, id] of outputIds) {
    const cell = new Logos(id, 0n, {}, `$output.${port}`);
    cells.push(cell);
    cellsByName.set(`$output.${port}`, cell);
  }

  const mappedInputs = {};
  for (const [port, nodeName] of Object.entries(definition.inputs)) {
    const id = ids.get(nodeName);
    if (id === undefined) throw new Error(`input ${port} points to unknown node ${nodeName}`);
    mappedInputs[port] = id;
  }

  return {
    definition,
    fabric: new Fabric(cells),
    inputs: Object.freeze(mappedInputs),
    outputs: Object.freeze(Object.fromEntries(outputIds)),
    cell(name) {
      const cell = cellsByName.get(name);
      if (!cell) throw new Error(`unknown cell ${name}`);
      return cell;
    },
  };
}

module.exports = {
  OP,
  edge,
  run,
  assertCausalTag,
  printTrace,
  local,
  output,
  geometry,
  compose,
  chain,
  compile,
};
