const Sim = @This();
const std = @import("std");
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

const ALIVE: u1 = 1;
const DEAD: u1 = 0;

const characters = [16][]const u8{
    " ", // 0b0000: DEAD  DEAD  DEAD  DEAD
    "▗", // 0b0001: DEAD  DEAD  DEAD  ALIVE
    "▖", // 0b0010: DEAD  DEAD  ALIVE DEAD
    "▄", // 0b0011: DEAD  DEAD  ALIVE ALIVE
    "▝", // 0b0100: DEAD  ALIVE DEAD  DEAD
    "▐", // 0b0101: DEAD  ALIVE DEAD  ALIVE
    "▞", // 0b0110: DEAD  ALIVE ALIVE DEAD
    "▟", // 0b0111: DEAD  ALIVE ALIVE ALIVE
    "▘", // 0b1000: ALIVE DEAD  DEAD  DEAD
    "▚", // 0b1001: ALIVE DEAD  DEAD  ALIVE
    "▌", // 0b1010: ALIVE DEAD  ALIVE DEAD
    "▙", // 0b1011: ALIVE DEAD  ALIVE ALIVE
    "▀", // 0b1100: ALIVE ALIVE DEAD  DEAD
    "▜", // 0b1101: ALIVE ALIVE DEAD  ALIVE
    "▛", // 0b1110: ALIVE ALIVE ALIVE DEAD
    "█", // 0b1111: ALIVE ALIVE ALIVE ALIVE
};

fn getCharacter(tl: u1, tr: u1, bl: u1, br: u1) []const u8 {
    const idx: u4 = (@as(u4, tl) << 3) |
        (@as(u4, tr) << 2) |
        (@as(u4, bl) << 1) |
        @as(u4, br);
    return characters[idx];
}

height: u32,
width: u32,
alive: f64,
step: u32,
world: []u1,
future_world: []u1,

pub fn init(allocator: std.mem.Allocator, height: u32, width: u32, alive_factor: f64) !Sim {
    const size = @as(usize, height) * @as(usize, width);
    const world = try allocator.alloc(u1, size);
    const future_world = try allocator.alloc(u1, size);

    var prng = std.Random.DefaultPrng.init(std.crypto.random.int(u64));
    const rand = prng.random();

    for (world) |*cell| {
        cell.* = if (rand.float(f64) <= alive_factor) ALIVE else DEAD;
    }

    return Sim{
        .height = height,
        .width = width,
        .alive = alive_factor,
        .step = 0,
        .world = world,
        .future_world = future_world,
    };
}

pub fn deinit(self: Sim, allocator: std.mem.Allocator) void {
    allocator.free(self.world);
    allocator.free(self.future_world);
}

pub fn format(self: Sim, writer: anytype) !void {
    var row: i32 = 0;
    while (row < self.height) : (row += 2) {
        var col: i32 = 0;
        while (col < self.width) : (col += 2) {
            const tl = self.get(row, col);
            const tr = self.get(row, col + 1);
            const bl = self.get((row + 1), col);
            const br = self.get((row + 1), col + 1);
            try writer.writeAll(getCharacter(tl, tr, bl, br));
        }
        try writer.writeByte('\n');
    }
    try writer.writeByte('\n');
}

fn get(self: Sim, row: i32, col: i32) u1 {
    if (row < 0 or row >= self.height or col < 0 or col >= self.width) {
        return 0;
    }
    return self.world[@as(u32, @intCast(row)) * self.width + @as(u32, @intCast(col))];
}

fn set(self: Sim, row: i32, col: i32, value: u1) void {
    self.future_world[@as(u32, @intCast(row)) * self.width + @as(u32, @intCast(col))] = value;
}

fn neighborhood(self: Sim, row: i32, col: i32) [9]u1 {
    return .{
        self.get(row - 1, col - 1),
        self.get(row - 1, col),
        self.get(row - 1, col + 1),
        self.get(row, col - 1),
        self.get(row, col),
        self.get(row, col + 1),
        self.get(row + 1, col - 1),
        self.get(row + 1, col),
        self.get(row + 1, col + 1),
    };
}

pub fn doStep(self: *Sim) void {
    var row: i32 = 0;
    while (row < self.height) : (row += 1) {
        var col: i32 = 0;
        while (col < self.width) : (col += 1) {
            const ns = self.neighborhood(row, col);
            const center = ns[4];

            var sum: u32 = 0;
            for (ns) |n| {
                sum += n;
            }
            sum -= center;
            if (sum <= 1 or sum > 3) {
                // under- or overpopulated
                self.set(row, col, DEAD);
            } else if (sum == 3) {
                // reproduction
                self.set(row, col, ALIVE);
            } else {
                // sum == 2: stay the same
                self.set(row, col, center);
            }
        }
    }
    // swap world with furture world
    const tmp = self.future_world;
    self.future_world = self.world;
    self.world = tmp;
    self.step += 1;
}

test "neighbors at edge" {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(dbg.deinit() == .ok);
    const alloc = dbg.allocator();

    var sim = try Sim.init(alloc, 10, 10, 0.0);
    defer sim.deinit(alloc);
    try expectEqualSlices(u1, &sim.neighborhood(0, 0), &[_]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    try expectEqualSlices(u1, &sim.neighborhood(9, 0), &[_]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    try expectEqualSlices(u1, &sim.neighborhood(0, 9), &[_]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    try expectEqualSlices(u1, &sim.neighborhood(9, 9), &[_]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 0 });
}

test "getCharacter - all 16 combinations" {
    try expectEqualStrings(" ", getCharacter(0, 0, 0, 0));
    try expectEqualStrings("▗", getCharacter(0, 0, 0, 1));
    try expectEqualStrings("▖", getCharacter(0, 0, 1, 0));
    try expectEqualStrings("▄", getCharacter(0, 0, 1, 1));
    try expectEqualStrings("▝", getCharacter(0, 1, 0, 0));
    try expectEqualStrings("▐", getCharacter(0, 1, 0, 1));
    try expectEqualStrings("▞", getCharacter(0, 1, 1, 0));
    try expectEqualStrings("▟", getCharacter(0, 1, 1, 1));
    try expectEqualStrings("▘", getCharacter(1, 0, 0, 0));
    try expectEqualStrings("▚", getCharacter(1, 0, 0, 1));
    try expectEqualStrings("▌", getCharacter(1, 0, 1, 0));
    try expectEqualStrings("▙", getCharacter(1, 0, 1, 1));
    try expectEqualStrings("▀", getCharacter(1, 1, 0, 0));
    try expectEqualStrings("▜", getCharacter(1, 1, 0, 1));
    try expectEqualStrings("▛", getCharacter(1, 1, 1, 0));
    try expectEqualStrings("█", getCharacter(1, 1, 1, 1));
}

test "init - all dead when alive_factor=0" {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(dbg.deinit() == .ok);
    const alloc = dbg.allocator();

    var sim = try Sim.init(alloc, 4, 6, 0.0);
    defer sim.deinit(alloc);

    try expectEqual(@as(u32, 4), sim.height);
    try expectEqual(@as(u32, 6), sim.width);
    try expectEqual(@as(u32, 0), sim.step);
    for (sim.world) |cell| try expectEqual(DEAD, cell);
}

test "init - all alive when alive_factor=1" {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(dbg.deinit() == .ok);
    const alloc = dbg.allocator();

    var sim = try Sim.init(alloc, 4, 6, 1.0);
    defer sim.deinit(alloc);

    for (sim.world) |cell| try expectEqual(ALIVE, cell);
}

test "get - out of bounds returns dead" {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(dbg.deinit() == .ok);
    const alloc = dbg.allocator();

    // Grid is all alive so any in-bounds cell would return ALIVE
    const sim = try Sim.init(alloc, 4, 4, 1.0);
    defer sim.deinit(alloc);

    try expectEqual(DEAD, sim.get(-1, 0));
    try expectEqual(DEAD, sim.get(0, -1));
    try expectEqual(DEAD, sim.get(4, 0));
    try expectEqual(DEAD, sim.get(0, 4));
    try expectEqual(DEAD, sim.get(-1, -1));
    try expectEqual(DEAD, sim.get(100, 100));
    // In-bounds cell returns ALIVE confirming the OOB path is distinct
    try expectEqual(ALIVE, sim.get(0, 0));
}

test "neighborhood - interior cell" {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(dbg.deinit() == .ok);
    const alloc = dbg.allocator();

    // 3x3 checkerboard, alive at corners and center:
    // 1 0 1
    // 0 1 0
    // 1 0 1
    var sim = try Sim.init(alloc, 3, 3, 0.0);
    defer sim.deinit(alloc);
    sim.world[0] = 1;
    sim.world[2] = 1;
    sim.world[4] = 1;
    sim.world[6] = 1;
    sim.world[8] = 1;

    // Center (1,1): all 8 neighbors are the known values above
    try expectEqualSlices(u1, &sim.neighborhood(1, 1), &[_]u1{ 1, 0, 1, 0, 1, 0, 1, 0, 1 });
    // Corner (0,0): top/left are OOB (0), right/bottom neighbors are (0,1)=0 and (1,1)=1 and (1,0)=0... wait:
    // tl=OOB, t=OOB, tr=OOB, l=OOB, c=(0,0)=1, r=(0,1)=0, bl=OOB, b=(1,0)=0, br=(1,1)=1
    try expectEqualSlices(u1, &sim.neighborhood(0, 0), &[_]u1{ 0, 0, 0, 0, 1, 0, 0, 0, 1 });
}

test "doStep - underpopulation: isolated cell dies, step increments" {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(dbg.deinit() == .ok);
    const alloc = dbg.allocator();

    var sim = try Sim.init(alloc, 5, 5, 0.0);
    defer sim.deinit(alloc);
    sim.world[2 * 5 + 2] = ALIVE; // single cell at center

    sim.doStep();

    for (sim.world) |cell| try expectEqual(DEAD, cell);
    try expectEqual(@as(u32, 1), sim.step);
}

test "doStep - overpopulation: cell with 4 neighbors dies" {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(dbg.deinit() == .ok);
    const alloc = dbg.allocator();

    // 5x5 plus/cross pattern:
    // . . . . .
    // . . X . .
    // . X X X .
    // . . X . .
    // . . . . .
    // Center (2,2) has 4 live orthogonal neighbors → dies
    var sim = try Sim.init(alloc, 5, 5, 0.0);
    defer sim.deinit(alloc);
    sim.world[1 * 5 + 2] = ALIVE;
    sim.world[2 * 5 + 1] = ALIVE;
    sim.world[2 * 5 + 2] = ALIVE;
    sim.world[2 * 5 + 3] = ALIVE;
    sim.world[3 * 5 + 2] = ALIVE;

    sim.doStep();

    try expectEqual(DEAD, sim.world[2 * 5 + 2]);
}

test "doStep - block is a still life" {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(dbg.deinit() == .ok);
    const alloc = dbg.allocator();

    // 4x4 grid, 2x2 block:
    // . . . .
    // . X X .   each live cell has exactly 3 live neighbors → survives
    // . X X .   dead border cells have at most 2 live neighbors → stay dead
    // . . . .
    var sim = try Sim.init(alloc, 4, 4, 0.0);
    defer sim.deinit(alloc);
    sim.world[1 * 4 + 1] = ALIVE;
    sim.world[1 * 4 + 2] = ALIVE;
    sim.world[2 * 4 + 1] = ALIVE;
    sim.world[2 * 4 + 2] = ALIVE;

    const expected = [_]u1{
        0, 0, 0, 0,
        0, 1, 1, 0,
        0, 1, 1, 0,
        0, 0, 0, 0,
    };

    sim.doStep();
    try expectEqualSlices(u1, &expected, sim.world);

    sim.doStep();
    try expectEqualSlices(u1, &expected, sim.world);
}

test "doStep - blinker oscillator (period 2)" {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(dbg.deinit() == .ok);
    const alloc = dbg.allocator();

    // 5x5 grid, horizontal blinker at row 2:
    // . . . . .
    // . . . . .
    // . X X X .   (2,1),(2,2),(2,3) alive
    // . . . . .
    // . . . . .
    var sim = try Sim.init(alloc, 5, 5, 0.0);
    defer sim.deinit(alloc);
    sim.world[2 * 5 + 1] = ALIVE;
    sim.world[2 * 5 + 2] = ALIVE;
    sim.world[2 * 5 + 3] = ALIVE;

    const horizontal = [_]u1{
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 1, 1, 1, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    };
    // After one step: vertical blinker at col 2
    // (2,1) and (2,3) each have 1 neighbor → die (underpopulation)
    // (2,2) has 2 neighbors → survives (sum==2, stay the same)
    // (1,2) and (3,2) each have 3 neighbors → born (reproduction)
    const vertical = [_]u1{
        0, 0, 0, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 0, 0, 0,
    };

    sim.doStep();
    try expectEqualSlices(u1, &vertical, sim.world);

    sim.doStep();
    try expectEqualSlices(u1, &horizontal, sim.world);
}

test "format - all dead 2x2" {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(dbg.deinit() == .ok);
    const alloc = dbg.allocator();

    var sim = try Sim.init(alloc, 2, 2, 0.0);
    defer sim.deinit(alloc);

    var buf = std.ArrayList(u8){};
    defer buf.deinit(alloc);

    try sim.format(buf.writer(alloc));
    try expectEqualStrings(" \n\n", buf.items);
}

test "format - all alive 2x2" {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(dbg.deinit() == .ok);
    const alloc = dbg.allocator();

    var sim = try Sim.init(alloc, 2, 2, 1.0);
    defer sim.deinit(alloc);

    var buf = std.ArrayList(u8){};
    defer buf.deinit(alloc);

    try sim.format(buf.writer(alloc));
    try expectEqualStrings("█\n\n", buf.items);
}

test "format - mixed 4x4" {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer std.debug.assert(dbg.deinit() == .ok);
    const alloc = dbg.allocator();

    // X . . X
    // . . . .
    // . . . .
    // X . . X
    var sim = try Sim.init(alloc, 4, 4, 0.0);
    defer sim.deinit(alloc);
    sim.world[0 * 4 + 0] = ALIVE;
    sim.world[0 * 4 + 3] = ALIVE;
    sim.world[3 * 4 + 0] = ALIVE;
    sim.world[3 * 4 + 3] = ALIVE;

    var buf = std.ArrayList(u8){};
    defer buf.deinit(alloc);

    try sim.format(buf.writer(alloc));
    // Row pair 0-1, col pair 0-1: tl=1 tr=0 bl=0 br=0 → "▘"
    // Row pair 0-1, col pair 2-3: tl=0 tr=1 bl=0 br=0 → "▝"
    // Row pair 2-3, col pair 0-1: tl=0 tr=0 bl=1 br=0 → "▖"
    // Row pair 2-3, col pair 2-3: tl=0 tr=0 bl=0 br=1 → "▗"
    try expectEqualStrings("▘▝\n▖▗\n\n", buf.items);
}
