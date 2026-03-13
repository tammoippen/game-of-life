const Sim = @This();
const std = @import("std");
const expectEqualSlices = std.testing.expectEqualSlices;

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
    "▛", // 0b1101: ALIVE ALIVE DEAD  ALIVE
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

fn neighbors(self: Sim, row: i32, col: i32) [9]u1 {
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
            const ns = self.neighbors(row, col);
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
    try expectEqualSlices(u1, &sim.neighbors(0, 0), &[_]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    try expectEqualSlices(u1, &sim.neighbors(9, 0), &[_]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    try expectEqualSlices(u1, &sim.neighbors(0, 9), &[_]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 0 });
    try expectEqualSlices(u1, &sim.neighbors(9, 9), &[_]u1{ 0, 0, 0, 0, 0, 0, 0, 0, 0 });
}
