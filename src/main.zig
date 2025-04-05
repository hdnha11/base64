const std = @import("std");
const lib = @import("base64_lib");

const max_size = 1e9;

const Mode = enum {
    enc,
    dec,
};

fn parseMode() Mode {
    const argv = std.os.argv;
    const mem = std.mem;
    var mode = Mode.enc;
    if (argv.len > 1 and mem.eql(u8, mem.span(argv[1]), "-d")) {
        mode = Mode.dec;
    }

    return mode;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    const base64 = lib.Base64.init();

    var gpa = std.heap.DebugAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const input = try stdin.readAllAlloc(allocator, max_size);
    const output = switch (parseMode()) {
        .enc => try base64.encode(allocator, input),
        .dec => try base64.decode(allocator, input),
    };

    try stdout.print("{s}", .{output});
}
