const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub const Base64 = struct {
    alphabet: *const [64]u8,
    index: [123]usize,

    pub fn init() Base64 {
        const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
        const numerals = "0123456789";
        const symbols = "+/";

        const alphabet = letters ++ numerals ++ symbols;
        var index: [123]usize = undefined;
        for (alphabet, 0..) |c, i| {
            index[c] = i;
        }

        return .{
            .alphabet = alphabet,
            .index = index,
        };
    }

    fn charAt(self: Base64, index: usize) u8 {
        return self.alphabet[index];
    }

    fn charIndex(self: Base64, char: u8) usize {
        if (char == '=') return 64;
        return self.index[char];
    }

    pub fn encode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) return "";

        const output_len = try calcEncodeLength(input);
        var output = try allocator.alloc(u8, output_len);
        var output_idx: usize = 0;
        var count: u8 = 0;
        var buf = [3]u8{ 0, 0, 0 };

        for (input) |c| {
            buf[count] = c;
            count += 1;

            if (count == 3) {
                output[output_idx] = self.charAt(buf[0] >> 2);
                output[output_idx + 1] = self.charAt(((buf[0] & 0x03) << 4) | (buf[1] >> 4));
                output[output_idx + 2] = self.charAt(((buf[1] & 0x0F) << 2) | (buf[2] >> 6));
                output[output_idx + 3] = self.charAt(buf[2] & 0x3F);

                output_idx += 4;
                count = 0;
            }
        }

        if (count == 2) {
            output[output_idx] = self.charAt(buf[0] >> 2);
            output[output_idx + 1] = self.charAt(((buf[0] & 0x03) << 4) | (buf[1] >> 4));
            output[output_idx + 2] = self.charAt((buf[1] & 0x0F) << 2);
            output[output_idx + 3] = '=';
        }

        if (count == 1) {
            output[output_idx] = self.charAt(buf[0] >> 2);
            output[output_idx + 1] = self.charAt((buf[0] & 0x03) << 4);
            output[output_idx + 2] = '=';
            output[output_idx + 3] = '=';
        }

        return output;
    }

    pub fn decode(self: Base64, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (input.len == 0) return "";

        const output_len = try calcDecodeLength(input);
        var output = try allocator.alloc(u8, output_len);
        var output_idx: usize = 0;
        var count: u8 = 0;
        var buf = [4]u8{ 0, 0, 0, 0 };

        for (input) |c| {
            buf[count] = @truncate(self.charIndex(c));
            count += 1;

            if (count == 4) {
                output[output_idx] = buf[0] << 2 | buf[1] >> 4;

                if (buf[2] != 64) {
                    output[output_idx + 1] = buf[1] << 4 | buf[2] >> 2;
                }

                if (buf[3] != 64) {
                    output[output_idx + 2] = buf[2] << 6 | buf[3];
                }

                output_idx += 3;
                count = 0;
            }
        }

        return output;
    }
};

test "charAt upper" {
    const base64 = Base64.init();

    for (0..26) |i| {
        try expectEqual('A' + i, base64.charAt(i));
    }
}

test "charAt lower" {
    const base64 = Base64.init();

    for (0..26) |i| {
        try expectEqual('a' + i, base64.charAt(i + 26));
    }
}

test "charAt numerals" {
    const base64 = Base64.init();

    for (0..10) |i| {
        try expectEqual('0' + i, base64.charAt(i + 52));
    }
}

test "charAt symbols" {
    const base64 = Base64.init();

    try expectEqual('+', base64.charAt(62));
    try expectEqual('/', base64.charAt(63));
}

test "charIndex upper" {
    const base64 = Base64.init();

    for ("ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0..) |c, i| {
        try expectEqual(i, base64.charIndex(c));
    }
}

test "charIndex lower" {
    const base64 = Base64.init();

    for ("abcdefghijklmnopqrstuvwxyz", 26..) |c, i| {
        try expectEqual(i, base64.charIndex(c));
    }
}

test "charIndex numerals" {
    const base64 = Base64.init();

    for ("0123456789", 52..) |c, i| {
        try expectEqual(i, base64.charIndex(c));
    }
}

test "charIndex symbols" {
    const base64 = Base64.init();

    for ("+/", 62..) |c, i| {
        try expectEqual(i, base64.charIndex(c));
    }
}

test "charIndex padding" {
    const base64 = Base64.init();

    try expectEqual(64, base64.charIndex('='));
}

test "encode" {
    var buf: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();

    const base64 = Base64.init();

    const input = "Testing some more stuff";
    const expected_output = "VGVzdGluZyBzb21lIG1vcmUgc3R1ZmY=";
    const output = try base64.encode(allocator, input);

    try expect(std.mem.eql(u8, expected_output, output));
}

test "decode" {
    var buf: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const allocator = fba.allocator();

    const base64 = Base64.init();

    const input = "VGVzdGluZyBzb21lIG1vcmUgc3R1ZmY=";
    const expected_output = "Testing some more stuff";
    const output = try base64.decode(allocator, input);

    try expect(std.mem.eql(u8, expected_output, output));
}

fn calcEncodeLength(input: []const u8) !usize {
    if (input.len < 3) {
        return 4;
    }

    const n = try std.math.divCeil(usize, input.len, 3);
    return n * 4;
}

test "calcEncodeLength" {
    try expectEqual(4, try calcEncodeLength(""));
    try expectEqual(4, try calcEncodeLength("1"));
    try expectEqual(4, try calcEncodeLength("12"));
    try expectEqual(4, try calcEncodeLength("123"));
    try expectEqual(8, try calcEncodeLength("1234"));
    try expectEqual(8, try calcEncodeLength("12345"));
    try expectEqual(8, try calcEncodeLength("123456"));
    try expectEqual(12, try calcEncodeLength("1234567"));
}

fn countPadding(input: []const u8) u8 {
    const max_pad = 2;
    var npad: u8 = 0;
    var i: u8 = 0;
    while (i < max_pad and input.len > i) : (i += 1) {
        if (input[input.len - i - 1] == '=') {
            npad += 1;
        }
    }

    return npad;
}

fn calcDecodeLength(input: []const u8) !usize {
    const npad = countPadding(input);

    if (input.len < 4) {
        return 3 - npad;
    }

    const n = try std.math.divFloor(usize, input.len, 4);
    return (n * 3) - npad;
}

test "calcDecodeLength" {
    try expectEqual(1, try calcDecodeLength("12=="));
    try expectEqual(2, try calcDecodeLength("123="));
    try expectEqual(3, try calcDecodeLength("1234"));
    try expectEqual(4, try calcDecodeLength("123456=="));
    try expectEqual(5, try calcDecodeLength("1234567="));
    try expectEqual(6, try calcDecodeLength("12345678"));
    try expectEqual(7, try calcDecodeLength("1234567890=="));
    try expectEqual(8, try calcDecodeLength("12345678900="));
    try expectEqual(9, try calcDecodeLength("123456789000"));
}
