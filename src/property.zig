const std = @import("std");
const trait = std.meta.trait;

pub const Error = error{
    TypeError,
    MissMatchCallback,
};

pub fn Property(comptime ValueType_: type) type {
    return struct {
        value: ValueType,
        next_bind_id: u32 = 1,
        allocator: std.mem.Allocator = undefined,
        binders: std.ArrayList(Binder) = undefined,

        const Self = @This();
        pub const ValueType = ValueType_;
        pub const InvalidBindId: u32 = 0;

        pub const Callback = *const fn (ctx: ?*anyopaque, value: ValueType) void;
        pub const Binder = struct {
            ctx: ?*anyopaque,
            callback: Callback,
            bind_id: u32,
        };

        pub fn init(self: *Self, allocator: std.mem.Allocator) void {
            self.allocator = allocator;
            self.binders = std.ArrayList(Binder).init(allocator);
        }

        pub fn deinit(self: Self) void {
            self.binders.deinit();
        }

        pub fn getValue(self: Self) ValueType {
            return self.value;
        }

        pub fn get(self: Self, comptime DateType: type) DateType {
            if (DateType == ValueType) {
                return self.value;
            } else if (trait.isNumber(ValueType)) {} else if (trait.isZigString(ValueType)) {} else if (trait.is(.Enum)(ValueType)) {} else if (trait.isContainer(ValueType)) {} else {
                @compileError("Unsupported ValueType!\n");
            }
        }

        pub fn setValue(self: *Self, v: ValueType) bool {
            const old_value = self.value;
            self.value = v;

            // const value_changed = !std.mem.eql(ValueType, old_value, self.value);
            const value_changed = (old_value != self.value);
            if (value_changed) {
                self.notify();
            }

            return value_changed;
        }

        pub fn update(self: *Self, v: anytype) void {
            const DataType = @TypeOf(v);
            if (DataType == ValueType) {
                self.value = v;
            } else if (trait.isNumber(ValueType)) {} else if (trait.isZigString(ValueType)) {} else if (trait.is(.Enum)(ValueType)) {} else if (trait.isContainer(ValueType)) {} else {
                @compileError("Unsupported ValueType!\n");
            }
        }

        pub fn set(self: *Self, v: anytype) bool {
            const old_value = self.value;
            update(v);

            const value_changed = (old_value != self.value);
            if (value_changed) {
                self.notify();
            }

            return value_changed;
        }

        pub fn bind(self: *Self, ctx: anytype, comptime CallbackStruct: type) !u32 {
            var bind_id: u32 = Self.InvalidBindId;
            if (!@hasDecl(CallbackStruct, "onValueChanged")) {
                return Error.MissMatchCallback;
            }

            const CtxType = @TypeOf(ctx);
            const any_ctx: ?*anyopaque = if (CtxType != @TypeOf(null))
                @constCast(@ptrCast(ctx))
            else
                null;

            const callback = struct {
                fn f(c: ?*anyopaque, value: ValueType) void {
                    if (CtxType != @TypeOf(null)) {
                        const the_ctx: CtxType = @alignCast(@ptrCast(c.?));
                        CallbackStruct.onValueChanged(the_ctx, value);
                    } else {
                        CallbackStruct.onValueChanged(value);
                    }
                }
            }.f;

            bind_id = self.next_bind_id;
            try self.binders.append(Binder{ .ctx = any_ctx, .callback = callback, .bind_id = bind_id });
            self.next_bind_id += 1;

            return bind_id;
        }

        pub fn bindWidget(self: *Self, widget: anytype, comptime CallbackStruct: type) !u32 {
            const bind_id = try self.bind(widget, CallbackStruct);
            _ = bind_id;
        }

        pub fn unbind(self: *Self, ctx: anytype) void {
            const CtxType = @TypeOf(ctx);
            if (CtxType == @TypeOf(null)) {
                return;
            }

            const the_ctx: *anyopaque = @constCast(@ptrCast(ctx));
            for (self.binders.items, 0..) |binder, i| {
                if (binder.ctx) |binded_ctx| {
                    if (binded_ctx == the_ctx) {
                        _ = self.binders.swapRemove(i);
                        std.debug.print("{s} unbind {s}\n", .{ @typeName(Self), @typeName(CtxType) });
                    }
                }
            }
        }

        pub fn notify(self: Self) void {
            for (self.binders.items) |binder| {
                binder.callback(binder.ctx, self.value);
            }
        }
    };
}

pub const Type = enum {
    Integral,
    //     float,
    String,
    //     pos,
    //     size,
    //     alignment,
    //     style,
    //     states,
    //     flags,
};

pub const Integral = struct {
    value: i32 = 0,

    pub fn get(self: Integral, comptime ValueType: type) ValueType {
        if (trait.isIntegral(ValueType)) {
            return @intCast(self.value);
        } else if (trait.isFloat(ValueType)) {
            return @floatCast(self.value);
        } else if (trait.isZigString(ValueType)) {
            var buf: [32:0]u8 = undefined;
            return std.fmt.bufPrintZ(buf, "{d}", self.value) catch |e| @errorName(e);
        } else {
            @compileError("Unsupported ValueType!\n");
        }
    }

    pub fn set(self: Integral, v: anytype) bool {
        const ValueType = @TypeOf(v);
        const old_value = self.value;
        if (trait.isNumber(ValueType)) {
            self.value = @intCast(v);
        } else if (trait.isZigString(ValueType)) {
            self.value = std.fmt.parseInt(@TypeOf(self.value), v, 10) catch 0;
        } else {
            @compileError("Unsupported ValueType!\n");
        }

        return old_value != self.value;
    }
};

pub const String = struct {
    value: []const u8 = "",
    number_buf: [64]u8,

    pub fn get(self: Integral, comptime ValueType: type) ValueType {
        if (trait.isIntegral(ValueType)) {
            return std.fmt.parseInt(ValueType, self.value, 10) catch 0;
        } else if (trait.isFloat(ValueType)) {
            return std.fmt.parseFloat(ValueType, self.value) catch 0;
        } else if (trait.isZigString(ValueType)) {
            return self.value;
        } else {
            @compileError("Unsupported ValueType!\n");
        }
    }

    pub fn set(self: Integral, v: anytype) bool {
        const ValueType = @TypeOf(v);
        const old_value = self.value;
        if (trait.isIntegral(ValueType)) {
            self.value = std.fmt.bufPrintZ(self.number_buf, "{d}", .{v}) catch "";
        } else if (trait.isFloat(ValueType)) {
            self.value = std.fmt.bufPrintZ(self.number_buf, "{f}", .{v}) catch "";
        } else if (trait.isZigString(ValueType)) {
            self.value = v;
        } else {
            @compileError("Unsupported ValueType!\n");
        }

        return !std.mem.eql(u8, old_value, self.value);
    }
};
