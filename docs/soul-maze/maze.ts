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
