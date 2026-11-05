export const MAZE_COLS = 23;
export const MAZE_ROWS = 13;

type Cell = [number, number];

function rand(n: number): number {
  return Math.floor(Math.random() * n);
}

function normalize(cells: Cell[]): Cell[] {
  const minX = Math.min(...cells.map((cell) => cell[0]));
  const minY = Math.min(...cells.map((cell) => cell[1]));
  return cells.map(([x, y]) => [x - minX, y - minY] as Cell).sort((a, b) => a[1] - b[1] || a[0] - b[0]);
}

function orientations(cells: Cell[]): Cell[][] {
  const seen = new Set<string>();
  const out: Cell[][] = [];
  let cur = cells;
  for (let turn = 0; turn < 4; turn++) {
    for (const flip of [false, true]) {
      const next = normalize(cur.map(([x, y]) => [flip ? -x : x, y] as Cell));
      const key = next.map((cell) => cell.join(",")).join(";");
      if (!seen.has(key)) {
        seen.add(key);
        out.push(next);
      }
    }
    cur = cur.map(([x, y]) => [y, -x] as Cell);
  }
  return out;
}

// Straights may be absent. Bent pieces can repeat up to six times.
const SHAPES: { name: string; cells: Cell[]; min: number; max: number }[] = [
  { name: "i2", cells: [[0, 0], [1, 0]], min: 0, max: 2 },
  { name: "i3", cells: [[0, 0], [1, 0], [2, 0]], min: 0, max: 6 },
  { name: "i4", cells: [[0, 0], [1, 0], [2, 0], [3, 0]], min: 0, max: 4 },
  { name: "i5", cells: [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]], min: 0, max: 1 },
  { name: "l3", cells: [[0, 0], [1, 0], [0, 1]], min: 0, max: 6 },
  { name: "l4", cells: [[0, 0], [1, 0], [0, 1], [0, 2]], min: 3, max: 6 },
  { name: "chunk", cells: [[0, 0], [1, 0], [0, 1], [1, 1], [0, 2]], min: 2, max: 6 },
  { name: "hook", cells: [[0, 0], [0, 1], [1, 1], [2, 1], [0, 2]], min: 2, max: 6 },
  { name: "ell5", cells: [[0, 0], [1, 0], [2, 0], [0, 1], [0, 2]], min: 1, max: 6 },
  { name: "ell6", cells: [[0, 0], [1, 0], [2, 0], [0, 1], [0, 2], [0, 3]], min: 1, max: 6 },
];

const FORMS = SHAPES.map((shape) => ({ ...shape, forms: orientations(shape.cells) }));

function openTile(grid: string[][], x: number, y: number): boolean {
  const tile = grid[y]?.[x];
  return tile === "." || tile === "o" || tile === "P";
}

function wideFloors(grid: string[][]): number {
  let count = 0;
  for (let y = 0; y < MAZE_ROWS - 1; y++) {
    for (let x = 0; x < MAZE_COLS - 1; x++) {
      if (openTile(grid, x, y) && openTile(grid, x + 1, y) && openTile(grid, x, y + 1) && openTile(grid, x + 1, y + 1)) count++;
    }
  }
  return count;
}

function canPlace(grid: string[][], cells: Cell[], ox: number, oy: number, reserved: Set<string>): Cell[] | null {
  const abs: Cell[] = [];
  for (const [x, y] of cells) {
    const ax = ox + x;
    const ay = oy + y;
    if (ax < 1 || ay < 1 || ax >= MAZE_COLS - 1 || ay >= MAZE_ROWS - 1) return null;
    if (grid[ay][ax] !== "." || reserved.has(`${ax},${ay}`)) return null;
    abs.push([ax, ay]);
  }
  const self = new Set(abs.map((cell) => cell.join(",")));
  for (const [x, y] of abs) {
    for (const [dx, dy] of [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ]) {
      const nx = x + dx;
      const ny = y + dy;
      if (self.has(`${nx},${ny}`)) continue;
      if (nx > 0 && ny > 0 && nx < MAZE_COLS - 1 && ny < MAZE_ROWS - 1 && grid[ny][nx] === "#") return null;
    }
  }
  return abs;
}

function paint(grid: string[][], cells: Cell[]) {
  for (const [x, y] of cells) grid[y][x] = "#";
}

function covers(cells: Cell[], target: Cell[]): boolean {
  const need = new Set(target.map((cell) => cell.join(",")));
  return cells.some((cell) => need.has(cell.join(",")));
}

function placeCovering(grid: string[][], forms: Cell[][], reserved: Set<string>, target: Cell[]): Cell[] | null {
  const picks: Cell[][] = [];
  for (const form of forms) {
    for (let y = 1; y < MAZE_ROWS - 1; y++) {
      for (let x = 1; x < MAZE_COLS - 1; x++) {
        const abs = canPlace(grid, form, x, y, reserved);
        if (abs && covers(abs, target)) picks.push(abs);
      }
    }
  }
  return picks.length ? picks[rand(picks.length)] : null;
}

function firstWide(grid: string[][]): Cell[] | null {
  for (let y = 0; y < MAZE_ROWS - 1; y++) {
    for (let x = 0; x < MAZE_COLS - 1; x++) {
      if (openTile(grid, x, y) && openTile(grid, x + 1, y) && openTile(grid, x, y + 1) && openTile(grid, x + 1, y + 1)) {
        return [
          [x, y],
          [x + 1, y],
          [x, y + 1],
          [x + 1, y + 1],
        ];
      }
    }
  }
  return null;
}

function placeAnywhere(grid: string[][], forms: Cell[][], reserved: Set<string>): Cell[] | null {
  const hole = firstWide(grid);
  if (hole) {
    const covering = placeCovering(grid, forms, reserved, hole);
    if (covering) return covering;
  }
  const picks: Cell[][] = [];
  for (const form of forms) {
    for (let y = 1; y < MAZE_ROWS - 1; y++) {
      for (let x = 1; x < MAZE_COLS - 1; x++) {
        const abs = canPlace(grid, form, x, y, reserved);
        if (abs) picks.push(abs);
      }
    }
  }
  return picks.length ? picks[rand(picks.length)] : null;
}

function connected(grid: string[][]): boolean {
  const start: Cell = [11, 4];
  if (!openTile(grid, start[0], start[1])) return false;
  const seen = new Set<string>([`${start[0]},${start[1]}`]);
  const queue: Cell[] = [start];
  while (queue.length) {
    const [x, y] = queue.pop()!;
    for (const [dx, dy] of [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ]) {
      let nx = x + dx;
      const ny = y + dy;
      if (ny < 0 || ny >= MAZE_ROWS) continue;
      if (nx < 0 || nx >= MAZE_COLS) {
        if (grid[ny][0] === "#" || grid[ny][MAZE_COLS - 1] === "#") continue;
        nx = (nx + MAZE_COLS) % MAZE_COLS;
      }
      if (!openTile(grid, nx, ny)) continue;
      const key = `${nx},${ny}`;
      if (seen.has(key)) continue;
      seen.add(key);
      queue.push([nx, ny]);
    }
  }
  for (let y = 0; y < MAZE_ROWS; y++) {
    for (let x = 0; x < MAZE_COLS; x++) if (openTile(grid, x, y) && !seen.has(`${x},${y}`)) return false;
  }
  return true;
}

function stampHouse(grid: string[][]) {
  const house: [number, number, string][] = [
    [9, 5, "#"],
    [10, 5, "#"],
    [11, 5, "="],
    [12, 5, "#"],
    [13, 5, "#"],
    [9, 6, "#"],
    [10, 6, "G"],
    [11, 6, "G"],
    [12, 6, "G"],
    [13, 6, "#"],
    [9, 7, "#"],
    [10, 7, "G"],
    [11, 7, "G"],
    [12, 7, "G"],
    [13, 7, "#"],
    [9, 8, "#"],
    [10, 8, "#"],
    [11, 8, "#"],
    [12, 8, "#"],
    [13, 8, "#"],
  ];
  for (const [x, y, tile] of house) grid[y][x] = tile;
}

function sprinkle(grid: string[][]) {
  const open: Cell[] = [];
  for (let y = 0; y < MAZE_ROWS; y++) for (let x = 0; x < MAZE_COLS; x++) if (grid[y][x] === ".") open.push([x, y]);
  const souls: Cell[] = [];
  for (const corner of [
    [1, 1],
    [MAZE_COLS - 2, 1],
    [1, MAZE_ROWS - 2],
    [MAZE_COLS - 2, MAZE_ROWS - 2],
  ] as Cell[]) {
    let best: Cell | null = null;
    let bestD = 1e9;
    for (const cell of open) {
      if (souls.some((soul) => soul[0] === cell[0] && soul[1] === cell[1])) continue;
      const dist = Math.abs(cell[0] - corner[0]) + Math.abs(cell[1] - corner[1]);
      if (dist < bestD) {
        bestD = dist;
        best = cell;
      }
    }
    if (best) souls.push(best);
  }
  for (const [x, y] of souls) grid[y][x] = "o";
  const rest = open.filter((cell) => grid[cell[1]][cell[0]] === ".");
  rest.sort((a, b) => Math.abs(a[0] - 11) + Math.abs(a[1] - 11) - (Math.abs(b[0] - 11) + Math.abs(b[1] - 11)));
  const spawn = rest[0];
  if (spawn) grid[spawn[1]][spawn[0]] = "P";
}

function build(): { grid: string[][]; ok: boolean; wide: number } {
  const grid: string[][] = Array.from({ length: MAZE_ROWS }, () => Array(MAZE_COLS).fill("#"));
  for (let y = 1; y < MAZE_ROWS - 1; y++) for (let x = 1; x < MAZE_COLS - 1; x++) grid[y][x] = ".";
  for (const y of [1, 11]) {
    grid[y][0] = ".";
    grid[y][MAZE_COLS - 1] = ".";
  }
  stampHouse(grid);
  const reserved = new Set<string>();
  for (let y = 4; y <= 9; y++) for (let x = 8; x <= 14; x++) reserved.add(`${x},${y}`);
  for (const y of [1, 11]) for (const x of [1, 2, MAZE_COLS - 3, MAZE_COLS - 2]) reserved.add(`${x},${y}`);

  const tally: Record<string, number> = Object.fromEntries(FORMS.map((shape) => [shape.name, 0]));
  const armor: Cell[][] = [
    [[8, 3], [9, 3], [10, 3]],
    [[12, 3], [13, 3], [14, 3]],
    [[8, 10], [9, 10], [10, 10]],
    [[12, 10], [13, 10], [14, 10]],
    [[7, 4], [7, 5], [7, 6], [7, 7], [7, 8]],
    [[15, 4], [15, 5], [15, 6]],
    [[15, 8], [15, 9]],
  ];
  const armorNames = ["i3", "i3", "i3", "i3", "i5", "i3", "i2"];
  armor.forEach((cells, index) => {
    paint(grid, cells);
    tally[armorNames[index]]++;
  });

  const byName = Object.fromEntries(FORMS.map((shape) => [shape.name, shape]));
  const queue = FORMS.flatMap((shape) => Array.from({ length: Math.max(0, shape.min - tally[shape.name]) }, () => shape.name)).sort(() => Math.random() - 0.5);
  for (const name of queue) {
    const spot = placeAnywhere(grid, byName[name].forms, reserved);
    if (!spot) return { grid, ok: false, wide: wideFloors(grid) };
    paint(grid, spot);
    tally[name]++;
  }

  let guard = 0;
  while (wideFloors(grid) > 1 && guard < 40) {
    guard++;
    let sealed = false;
    for (let y = 0; y < MAZE_ROWS - 1 && !sealed; y++) {
      for (let x = 0; x < MAZE_COLS - 1 && !sealed; x++) {
        if (!(openTile(grid, x, y) && openTile(grid, x + 1, y) && openTile(grid, x, y + 1) && openTile(grid, x + 1, y + 1))) continue;
        const hole: Cell[] = [
          [x, y],
          [x + 1, y],
          [x, y + 1],
          [x + 1, y + 1],
        ];
        const options = [...FORMS].filter((shape) => tally[shape.name] < shape.max).sort(() => Math.random() - 0.5);
        for (const shape of options) {
          const placed = placeCovering(grid, shape.forms, reserved, hole);
          if (!placed) continue;
          paint(grid, placed);
          tally[shape.name]++;
          sealed = true;
          break;
        }
      }
    }
    if (!sealed) break;
  }

  const countsOk = FORMS.every((shape) => tally[shape.name] >= shape.min && tally[shape.name] <= shape.max);
  const wide = wideFloors(grid);
  return { grid, ok: countsOk && wide <= 1 && connected(grid), wide };
}

export function generateMaze(): string[][] {
  let best: string[][] | null = null;
  let bestWide = 1e9;
  for (let attempt = 0; attempt < 20; attempt++) {
    const made = build();
    if (made.ok) {
      sprinkle(made.grid);
      return made.grid;
    }
    if (made.wide < bestWide) {
      bestWide = made.wide;
      best = made.grid.map((row) => row.slice());
    }
  }
  const grid = best ?? build().grid;
  sprinkle(grid);
  return grid;
}
