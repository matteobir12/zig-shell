const std = @import("std");
const print = std.debug.print;

pub fn handle_sigint(_: i32) callconv(.c) void {
    print("\nUse 'exit' to exit\n> ", .{});
}

pub fn main() anyerror!void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    try stdout.print("*** connected to Bir Active Daemon Shell (BADSH) ***\n", .{});
    const sigact = std.c.Sigaction{
        .handler = .{ .handler = handle_sigint },
        .mask = std.c.empty_sigset,
        .flags = 0,
    };
    _ = std.c.sigaction(std.c.SIG.INT, &sigact, null);

    try ShellLoop(stdin, stdout);

    return;
}

fn ShellLoop(stdin: std.fs.File.Reader, stdout: std.fs.File.Writer) !void {
    while (true) {
        try stdout.print("> ", .{});

        const max_input = comptime 256;
        const max_args = comptime 16;

        var input_buffer: [max_input]u8 = undefined;

        const input_str = (try stdin.readUntilDelimiterOrEof(input_buffer[0..], '\n')) orelse {
            try stdout.print("\n", .{});
            return;
        };

        if (std.mem.eql(u8, input_buffer[0..input_str.len], "exit"))
            return;

        var arg_v_ptr: [max_args:null]?[*:0]const u8 = undefined;
        var head_idx: u8 = 0;
        var prev_idx: usize = 0;
        for (0..input_str.len) |i| {
            if (input_buffer[i] == ' ') {
                input_buffer[i] = 0x00;
                arg_v_ptr[head_idx] = @ptrCast(&input_buffer[prev_idx]);

                head_idx += 1;
                prev_idx = i + 1;
            }
        }

        input_buffer[input_str.len] = 0x00;
        if (prev_idx != input_str.len) {
            arg_v_ptr[head_idx] = @ptrCast(&input_buffer[prev_idx]);
            head_idx += 1;
        }

        arg_v_ptr[head_idx] = null;

        const file: [*:0]const u8 = @ptrCast(&input_buffer);

        const fork_pid = try std.posix.fork();
        if (fork_pid == 0) {
            // No need for path because it's included in the zig exec api.
            const env = [_:null]?[*:0]u8{};
            const err = std.posix.execvpeZ(file, arg_v_ptr[0..arg_v_ptr.len], env[0..env.len]);
            switch (err) {
                std.posix.ExecveError.SystemResources => try stdout.print("SystemResources!", .{}),
                std.posix.ExecveError.AccessDenied => {
                    try stdout.print("AccessDenied!\n", .{});
                },
                std.posix.ExecveError.PermissionDenied => {
                    try stdout.print("PermissionDenied!\n", .{});
                },
                std.posix.ExecveError.InvalidExe => {
                    try stdout.print("InvalidExe!\n", .{});
                },
                std.posix.ExecveError.FileSystem => {
                    try stdout.print("FileSystem!\n", .{});
                },
                std.posix.ExecveError.IsDir => {
                    try stdout.print("IsDir!\n", .{});
                },
                std.posix.ExecveError.FileNotFound => {
                    try stdout.print("Unknown Command!\n", .{});
                },
                std.posix.ExecveError.NotDir => {
                    try stdout.print("NotDir!\n", .{});
                },
                std.posix.ExecveError.FileBusy => {
                    try stdout.print("FileBusy!\n", .{});
                },
                std.posix.ExecveError.ProcessFdQuotaExceeded => {
                    try stdout.print("ProcessFdQuotaExceeded!\n", .{});
                },
                std.posix.ExecveError.SystemFdQuotaExceeded => {
                    try stdout.print("SystemFdQuotaExceeded!\n", .{});
                },
                std.posix.ExecveError.NameTooLong => {
                    try stdout.print("NameTooLong!", .{});
                },
                std.posix.ExecveError.Unexpected => {
                    try stdout.print("Unexpected!", .{});
                },
            }
        } else {
            const wait_result = std.posix.waitpid(fork_pid, 0);
            if (wait_result.status != 0) {
                try stdout.print("Command returned {}.\n", .{wait_result.status});
            }
        }
    }
}
