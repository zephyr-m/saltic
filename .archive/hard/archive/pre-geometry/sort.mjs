class Agent {
  constructor(id, value) {
    this.id = id
    this.value = value
    this.busy = false
  }
}

class Link {
  constructor(left, right) {
    this.left = left
    this.right = right
  }

  interact() {
    if (this.left.busy || this.right.busy) return false

    this.left.busy = true
    this.right.busy = true

    const offer = this.left.value
    const answer = this.right.value
    const changed = offer > answer

    if (changed) {
      // Each agent changes only its own memory after the handshake.
      this.left.value = answer
      this.right.value = offer
    }

    this.left.busy = false
    this.right.busy = false
    return changed
  }
}

class Fabric {
  constructor(values) {
    this.agents = values.map((value, id) => new Agent(id, value))
    this.links = this.agents.slice(1).map((agent, id) => new Link(this.agents[id], agent))
    this.pulses = 0
    this.rounds = 0
  }

  view() {
    return this.agents.map(agent => agent.value)
  }

  settled() {
    return this.links.every(link => link.left.value <= link.right.value)
  }

  pulse(offset) {
    for (let index = offset; index < this.links.length; index += 2) {
      this.links[index].interact()
      this.pulses += 1
    }
  }

  run(limit = 10_000) {
    while (!this.settled() && this.rounds < limit) {
      this.pulse(0)
      this.pulse(1)
      this.rounds += 1
    }

    if (!this.settled()) throw new Error('fabric did not settle')
    return this.view()
  }
}

const input = process.argv.slice(2).map(Number)
const values = input.length ? input : [9, 1, 7, 3, 8, 2, 6, 4, 5, 0]
const fabric = new Fabric(values)
const result = fabric.run()
const expected = [...values].sort((left, right) => left - right)

if (JSON.stringify(result) !== JSON.stringify(expected)) {
  throw new Error(`expected ${expected}, got ${result}`)
}

console.log(`input   ${values.join(' ')}`)
console.log(`output  ${result.join(' ')}`)
console.log(`agents  ${fabric.agents.length}`)
console.log(`rounds  ${fabric.rounds}`)
console.log(`pulses  ${fabric.pulses}`)
