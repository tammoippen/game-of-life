const std = @import("std");
const Writer = std.Io.Writer;
const Reader = std.Io.Reader;
const zli = @import("zli");
const Sim = @import("sim.zig");

const version_flag = zli.Flag{
    .name = "version",
    .shortcut = "v",
    .description = "Get version",
    .type = .Bool,
    .default_value = .{ .Bool = false },
};
const height_flag = zli.Flag{
    .name = "height",
    .shortcut = null,
    .description = "World height (even and greater 0)",
    .type = .Int,
    .default_value = .{ .Int = 40 },
};
const width_flag = zli.Flag{
    .name = "width",
    .shortcut = null,
    .description = "World width (even and greater 0)",
    .type = .Int,
    .default_value = .{ .Int = 80 },
};
const sleep_flag = zli.Flag{
    .name = "sleep",
    .shortcut = null,
    .description = "Sleep between steps [ms]",
    .type = .Int,
    .default_value = .{ .Int = 200 },
};
const alive_flag = zli.Flag{
    .name = "alive",
    .shortcut = null,
    .description = "World alive factor for init (0, 1)",
    .type = .String,
    .default_value = .{ .String = "0.5" },
};

pub fn build(writer: *Writer, reader: *Reader, allocator: std.mem.Allocator) !*zli.Command {
    const cmd = try zli.Command.init(writer, reader, allocator, .{
        .name = "game-of-life",
        .description = "Conway's Game of Life",
        .version = .{ .major = 0, .minor = 0, .patch = 1, .pre = null, .build = null },
    }, run);

    try cmd.addFlag(version_flag);
    try cmd.addFlag(height_flag);
    try cmd.addFlag(width_flag);
    try cmd.addFlag(sleep_flag);
    try cmd.addFlag(alive_flag);

    return cmd;
}

fn run(ctx: zli.CommandContext) !void {
    const version = ctx.flag("version", bool);
    if (version) {
        try ctx.writer.print("{s} v{f}\n", .{ ctx.root.options.name, ctx.root.options.version.? });
        return;
    }
    const help = ctx.flag("help", bool);
    if (help) {
        try ctx.root.printHelp();
        return;
    }
    const height = ctx.flag("height", i32);
    if (height <= 0 or @mod(height, 2) != 0) {
        try ctx.writer.print("Error: height ({d}) has to be greater 0 and even.\n\n", .{height});
        try ctx.root.printHelp();
        std.process.exit(1);
    }
    const width = ctx.flag("width", i32);
    if (width <= 0 or @mod(width, 2) != 0) {
        try ctx.writer.print("Error: width ({d}) has to be greater 0 and even.\n\n", .{width});
        try ctx.root.printHelp();
        std.process.exit(1);
    }
    const sleep = ctx.flag("sleep", u64);
    const alive_str = ctx.flag("alive", []const u8);
    const alive = std.fmt.parseFloat(f64, alive_str) catch {
        try ctx.writer.print("Error parsing alive ({s}) to float.\n\n", .{alive_str});
        try ctx.root.printHelp();
        std.process.exit(1);
    };
    var sim = try Sim.init(ctx.allocator, @intCast(height), @intCast(width), alive);
    defer sim.deinit(ctx.allocator);
    while (true) {
        try ctx.writer.writeAll("\x1Bc");
        try ctx.writer.print("{f}\n\nStep: {d}", .{ sim, sim.step });
        sim.doStep();
        std.Thread.sleep(1000000 * sleep);
    }
}
