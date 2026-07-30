#!/usr/bin/env node

// Fixed local chemistry. Programs differ only by their initial particle graph.
const PLUS = "+";
const MINUS = "-";

let nextNodeId = 1;

function chain(sign, length) {
  let head = null;
  for (let index = 0; index < length; index += 1) {
    head = { id: nextNodeId++, sign, next: head };
  }
  return head;
}

function job(name, left, right) {
  return {
    name,
    inlets: [left, right],
    result: null,
    locked: false,
    rewrites: 0,
  };
}

function particleCount(head) {
  let count = 0;
  for (let node = head; node !== null; node = node.next) count += 1;
  return count;
}

function decode(head) {
  if (head === null) return 0;
  const sign = head.sign;
  let magnitude = 0;
  for (let node = head; node !== null; node = node.next) {
    if (node.sign !== sign) throw new Error("result chain is not normalised");
    magnitude += 1;
  }
  return sign === PLUS ? magnitude : -magnitude;
}

function snapshot(currentJob) {
  const pending = currentJob.inlets.map(particleCount).join("+");
  const value = decode(currentJob.result);
  return `${currentJob.name}{pending=${pending}, result=${value}}`;
}

// One worker performs exactly one local rewrite at one job boundary.
function interact(worker, currentJob) {
  if (currentJob.locked) return null;
  const inletIndex = currentJob.inlets.findIndex((head) => head !== null);
  if (inletIndex < 0) return null;

  currentJob.locked = true;
  const particle = currentJob.inlets[inletIndex];
  currentJob.inlets[inletIndex] = particle.next;

  let rule;
  if (currentJob.result !== null && currentJob.result.sign !== particle.sign) {
    const opposite = currentJob.result;
    currentJob.result = opposite.next;
    rule = `${particle.sign}${opposite.sign} -> empty`;
  } else {
    particle.next = currentJob.result;
    currentJob.result = particle;
    rule = `${particle.sign} -> output`;
  }
  currentJob.rewrites += 1;

  return {
    worker,
    job: currentJob.name,
    inlet: inletIndex,
    rule,
    particle: particle.id,
  };
}

function finished(jobs) {
  return jobs.every((currentJob) => currentJob.inlets.every((head) => head === null));
}

function simulate(jobs, massAtTick) {
  let tick = 0;
  let cursor = 0;
  const trace = [];

  while (!finished(jobs)) {
    tick += 1;
    for (const currentJob of jobs) currentJob.locked = false;

    const mass = massAtTick(tick);
    if (!Number.isInteger(mass) || mass < 1) throw new Error("mass must be a positive integer");

    const events = [];
    for (let worker = 0; worker < mass; worker += 1) {
      let event = null;
      for (let attempt = 0; attempt < jobs.length; attempt += 1) {
        const currentJob = jobs[(cursor + attempt) % jobs.length];
        event = interact(worker, currentJob);
        if (event !== null) {
          cursor = (cursor + attempt + 1) % jobs.length;
          break;
        }
      }
      if (event !== null) events.push(event);
    }

    if (events.length === 0) throw new Error("chemistry deadlocked");
    for (const currentJob of jobs) currentJob.locked = false;
    trace.push({ tick, mass, events, state: jobs.map(snapshot) });
  }
  return trace;
}

// Initial graph only. There are no ADD or SUB operations in the reducer.
const jobs = [
  job("A", chain(PLUS, 5), chain(PLUS, 3)),
  job("B", chain(PLUS, 4), chain(MINUS, 2)),
];

// Free computational mass changes while both graphs are alive.
const trace = simulate(jobs, (tick) => [1, 2, 4, 2][(tick - 1) % 4]);

console.log("initial: A=(+++++ | +++), B=(++++ | --)");
for (const row of trace) {
  const events = row.events
    .map((event) => `w${event.worker}:${event.job}[${event.inlet}] ${event.rule}`)
    .join("; ");
  console.log(
    `tick ${String(row.tick).padStart(2, "0")} mass=${row.mass}  ${events}  ` +
      row.state.join("  "),
  );
}

const results = Object.fromEntries(jobs.map((currentJob) => [currentJob.name, decode(currentJob.result)]));
if (results.A !== 8 || results.B !== 2) {
  throw new Error(`wrong normal forms: ${JSON.stringify(results)}`);
}
if (jobs.some((currentJob) => currentJob.locked)) {
  throw new Error("job remained locked");
}

console.log(`normal forms: A=${results.A}, B=${results.B}`);
console.log(`rewrites: A=${jobs[0].rewrites}, B=${jobs[1].rewrites}`);
