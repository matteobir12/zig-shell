const std = @import("std");
const print = std.debug.print;

pub fn main() anyerror!void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    try stdout.print("*** Shell connected! ***\n", .{});
    try ShellLoop(stdin, stdout);

    return;
}

fn ShellLoop(stdin: std.fs.File.Reader, stdout: std.fs.File.Writer) !void {
    while (true) {
        try stdout.print("> ", .{});

        const max_input = comptime 256;
        const max_args = comptime 16;

        var input_buffer: [max_input]u8 align(8) = undefined;

        const input_str = (try stdin.readUntilDelimiterOrEof(input_buffer[0..], '\n')) orelse {
            try stdout.print("\n", .{});
            return;
        };

        var arg_v_ptr: [max_args:null]?[*:0]const u8 = undefined;
        var head_idx: u8 = 0;
        for (0..input_str.len) |i| {
            if (input_buffer[i] == ' ') {
                input_buffer[i] = 0x00;
                arg_v_ptr[head_idx] = @ptrCast(&input_buffer[i]);
                head_idx += 1;
            }
        }

        input_buffer[input_str.len] = 0x00;
        arg_v_ptr[head_idx] = @ptrCast(&input_buffer[input_str.len]);
        head_idx += 1;

        arg_v_ptr[head_idx] = null;

        const file: [*:0]const u8 = @ptrCast(&input_buffer);

        const fork_pid = try std.posix.fork();
        if (fork_pid == 0) {
            // TODO get real path
            const env = [_:null]?[*:0]u8{};
            const err = std.posix.execvpeZ(file, arg_v_ptr[0..arg_v_ptr.len], env[0..env.len]);
            switch (err) {
                std.posix.ExecveError.SystemResources => try stdout.print("SystemResources!", .{}),
                std.posix.ExecveError.AccessDenied => {
                    try stdout.print("AccessDenied!", .{});
                },
                std.posix.ExecveError.PermissionDenied => {
                    try stdout.print("PermissionDenied!", .{});
                },
                std.posix.ExecveError.InvalidExe => {
                    try stdout.print("InvalidExe!", .{});
                },
                std.posix.ExecveError.FileSystem => {
                    try stdout.print("FileSystem!", .{});
                },
                std.posix.ExecveError.IsDir => {
                    try stdout.print("IsDir!", .{});
                },
                std.posix.ExecveError.FileNotFound => {
                    try stdout.print("FileNotFound!", .{});
                },
                std.posix.ExecveError.NotDir => {
                    try stdout.print("NotDir!", .{});
                },
                std.posix.ExecveError.FileBusy => {
                    try stdout.print("FileBusy!", .{});
                },
                std.posix.ExecveError.ProcessFdQuotaExceeded => {
                    try stdout.print("ProcessFdQuotaExceeded!", .{});
                },
                std.posix.ExecveError.SystemFdQuotaExceeded => {
                    try stdout.print("SystemFdQuotaExceeded!", .{});
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
