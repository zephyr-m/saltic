"use strict";

const OP = Object.freeze({ NOP: 0b00, INC: 0b01, DEC: 0b10, HALT: 0b11 });
const WIDTH = 16;
const HEIGHT = 16;
const CELLS = WIDTH * HEIGHT;
const ENERGY = 4;

class Logos {
  constructor(id) {
    this.id = id;
    this.counter = 0n;
    this.halted = false;
    this.inc = null;
    this.dec = null;
    this.zero = null;
    this.outbox = null;
  }

  ready(outboxReady) {
    return !this.halted && (this.outbox === null || outboxReady);
  }

  step(sticker = null, outboxReady = true) {
    const accepted = sticker !== null && this.ready(outboxReady);
    if (this.outbox !== null && outboxReady) this.outbox = null;
    if (!accepted) return false;

    let reaction = null;
    if (sticker.opcode === OP.INC) {
      this.counter = BigInt.asUintN(64, this.counter + 1n);
      reaction = this.inc;
    } else if (sticker.opcode === OP.DEC) {
      if (this.counter === 0n) reaction = this.zero;
      else {
        this.counter--;
        reaction = this.dec;
      }
    } else if (sticker.opcode === OP.HALT) {
      this.halted = true;
    }

    if (reaction?.valid) {
      this.outbox = {
        target: reaction.target,
        sticker: { opcode: reaction.opcode, data: sticker.data },
      };
    }
    return true;
  }
}

function neighbours(id) {
  const x = id % WIDTH;
  const y = Math.floor(id / WIDTH);
  const result = [];
  if (y > 0) result.push(id - WIDTH);
  if (y + 1 < HEIGHT) result.push(id + WIDTH);
  if (x > 0) result.push(id - 1);
  if (x + 1 < WIDTH) result.push(id + 1);
  return result;
}

class Fabric {
  constructor() { this.reset(); }

  reset() {
    this.logos = Array.from({ length: CELLS }, (_, id) => new Logos(id));
    this.tick = 0;
    this.pulses = 0;
    this.collisions = 0;
    this.frontier = new Set();
    this.visited = new Set();
  }

  command(id, opcode, times = 1) {
    for (let count = 0; count < times; count++) {
      this.logos[id].step({ opcode, data: 0n }, true);
      this.pulses++;
    }
  }

  inject(x, y) {
    const id = y * WIDTH + x;
    this.frontier.add(id);
    this.visited.add(id);
  }

  step() {
    // This wave scheduler is an external protocol client. The Logos themselves
    // execute only the four operations specified in LOGOS_SPEC.md.
    this.logos.forEach((logos, id) => {
      if (logos.counter > 0n) this.command(id, OP.DEC);
    });
    const next = new Set();
    for (const id of this.frontier) {
      this.command(id, OP.INC, ENERGY);
      for (const target of neighbours(id)) {
        if (!this.visited.has(target)) {
          this.visited.add(target);
          next.add(target);
        }
      }
    }
    this.frontier = next;
    this.tick++;
  }

  showText(text) {
    const pixels = glyphPixels(text.toUpperCase().slice(0, 4));
    // Four DEC clear any previous 3-bit pixel state.
    for (let pass = 0; pass < ENERGY; pass++) {
      this.logos.forEach((logos, id) => this.command(id, OP.DEC));
      this.tick++;
    }
    // Four INC bring selected Logos to maximum brightness.
    for (let pass = 0; pass < ENERGY; pass++) {
      pixels.forEach(id => this.command(id, OP.INC));
      this.tick++;
    }
  }
}

function verifyLogosV0() {
  const logos = new Logos(0);
  logos.counter = 1n;
  logos.inc = { valid: true, opcode: OP.DEC, target: 9 };
  logos.dec = { valid: true, opcode: OP.INC, target: 10 };
  logos.zero = { valid: true, opcode: OP.HALT, target: 11 };
  if (!logos.step({ opcode: OP.INC, data: 0x1234n }, true)) throw new Error("INC was not accepted");
  if (logos.counter !== 2n || logos.outbox.target !== 9 || logos.outbox.sticker.data !== 0x1234n)
    throw new Error("Logos v0 INC conformance failed");
  if (logos.step({ opcode: OP.DEC, data: 0x5678n }, false))
    throw new Error("Logos v0 backpressure conformance failed");
  logos.step({ opcode: OP.DEC, data: 0x5678n }, true);
  if (logos.counter !== 1n || logos.outbox.target !== 10)
    throw new Error("Logos v0 DEC conformance failed");
}

verifyLogosV0();

// 3×5 font ROM. Each hexadecimal digit is one three-bit row.
const FONT = Object.freeze({
  " ": "00000", A: "27555", B: "65756", C: "74447", D: "65556",
  E: "74747", F: "74744", G: "74657", H: "55755", I: "72227",
  J: "11157", K: "56565", L: "44447", M: "75755", N: "76555",
  O: "75557", P: "75744", Q: "75576", R: "75765", S: "74617",
  T: "72222", U: "55557", V: "55552", W: "55577", X: "55255",
  Y: "55222", Z: "71247", "0": "75557", "1": "26227", "2": "71747",
  "3": "71717", "4": "55711", "5": "74717", "6": "74757", "7": "71111",
  "8": "75757", "9": "75717", "-": "00700", ".": "00002"
});

function glyphPixels(text) {
  const pixels = new Set();
  [...text.padEnd(4, " ")].forEach((character, slot) => {
    const rows = FONT[character] || FONT[" "];
    [...rows].forEach((bits, row) => {
      const mask = Number(bits);
      for (let column = 0; column < 3; column++) {
        if (mask & (1 << (2 - column))) {
          const x = slot * 4 + column;
          const y = 5 + row;
          pixels.add(y * WIDTH + x);
        }
      }
    });
  });
  return pixels;
}

const fabric = new Fabric();
const nativeCanvas = document.querySelector("#native");
const zoomCanvas = document.querySelector("#zoom");
const nativeContext = nativeCanvas.getContext("2d");
const zoomContext = zoomCanvas.getContext("2d");
const status = document.querySelector("#status");
const runButton = document.querySelector("#run");
const textInput = document.querySelector("#text");
let running = false;
let previousTime = 0;

function colour(counter, halted) {
  if (halted) return [255, 65, 90];
  return [
    [2, 6, 7],
    [18, 64, 66],
    [25, 120, 122],
    [54, 190, 190],
    [210, 255, 250],
  ][Math.min(Number(counter), ENERGY)];
}

function draw() {
  const image = nativeContext.createImageData(WIDTH, HEIGHT);
  fabric.logos.forEach((logos, index) => {
    const [r, g, b] = colour(logos.counter, logos.halted);
    const at = index * 4;
    image.data[at] = r;
    image.data[at + 1] = g;
    image.data[at + 2] = b;
    image.data[at + 3] = 255;
  });
  nativeContext.putImageData(image, 0, 0);
  zoomContext.putImageData(image, 0, 0);
  const active = fabric.logos.filter(logos => logos.counter > 0n).length;
  status.textContent = `tick     ${fabric.tick}\nactive   ${active}/${CELLS}\npulses   ${fabric.pulses}\ncollision ${fabric.collisions}`;
}

function frame(time) {
  if (running && time - previousTime >= 120) {
    fabric.step();
    draw();
    previousTime = time;
  }
  requestAnimationFrame(frame);
}

runButton.addEventListener("click", () => {
  running = !running;
  runButton.textContent = running ? "Пауза" : "Пуск";
});
document.querySelector("#step").addEventListener("click", () => { fabric.step(); draw(); });
document.querySelector("#seed").addEventListener("click", () => { fabric.inject(7, 7); draw(); });
document.querySelector("#reset").addEventListener("click", () => { fabric.reset(); running = false; runButton.textContent = "Пуск"; draw(); });
textInput.addEventListener("input", () => {
  running = false;
  runButton.textContent = "Пуск";
  fabric.showText(textInput.value);
  draw();
});
zoomCanvas.addEventListener("click", event => {
  const bounds = zoomCanvas.getBoundingClientRect();
  const x = Math.floor((event.clientX - bounds.left) * WIDTH / bounds.width);
  const y = Math.floor((event.clientY - bounds.top) * HEIGHT / bounds.height);
  fabric.inject(x, y);
  draw();
});

fabric.inject(7, 7);
draw();
requestAnimationFrame(frame);
