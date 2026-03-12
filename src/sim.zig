const Sim = @This();
const std = @import("std");

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

pub fn init(allocator: std.mem.Allocator, height: u32, width: u32, alive_factor: f64) !Sim {
    const size = @as(usize, height) * @as(usize, width);
    const world = try allocator.alloc(u1, size);

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
    };
}

pub fn deinit(self: Sim, allocator: std.mem.Allocator) void {
    allocator.free(self.world);
}

pub fn format(self: Sim, writer: anytype) !void {
    var row: u32 = 0;
    while (row < self.height) : (row += 2) {
        var col: u32 = 0;
        while (col < self.width) : (col += 2) {
            const tl = self.world[row * self.width + col];
            const tr = self.world[row * self.width + col + 1];
            const bl = self.world[(row + 1) * self.width + col];
            const br = self.world[(row + 1) * self.width + col + 1];
            try writer.writeAll(getCharacter(tl, tr, bl, br));
        }
        try writer.writeByte('\n');
    }
    try writer.writeByte('\n');
}
