const std = @import("std");
const trait = std.meta.trait;
const c = @cImport({
    @cInclude("string.h");
});

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

        pub const ValueChangedCallback = *const fn (ctx: ?*anyopaque, value: ValueType) void;
        pub const DeleteCallback = *const fn (ctx: ?*anyopaque) void;
        pub const Binder = struct {
            ctx: ?*anyopaque,
            on_value_changed: ValueChangedCallback,
            on_delete: ?DeleteCallback = null,
            bind_id: u32,

            pub fn setDeleteCallback(self: Binder, comptime CallbackStruct: type) !void {
                if (!@hasDecl(CallbackStruct, "onDelete")) {
                    return Error.MissMatchCallback;
                }

                self.on_delete = CallbackStruct.onDelete;
            }
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

        pub fn eql(self: Self, v: ValueType) bool {
            return c.memcmp(@ptrCast(&self.value), @ptrCast(&v), @sizeOf(ValueType)) == 0;
        }

        pub fn setValue(self: *Self, v: ValueType) bool {
            const value_changed = !self.eql(v);
            if (value_changed) {
                self.value = v;
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
                fn f(actx: ?*anyopaque, value: ValueType) void {
                    if (CtxType != @TypeOf(null)) {
                        const the_ctx: CtxType = @alignCast(@ptrCast(actx.?));
                        CallbackStruct.onValueChanged(the_ctx, value);
                    } else {
                        CallbackStruct.onValueChanged(value);
                    }
                }
            }.f;

            bind_id = self.next_bind_id;
            try self.binders.append(Binder{ .ctx = any_ctx, .on_value_changed = callback, .bind_id = bind_id });
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
                        std.debug.print("unbind {s}\n", .{@typeName(CtxType)});
                    }
                }
            }
        }

        pub fn notify(self: Self) void {
            for (self.binders.items) |binder| {
                binder.on_value_changed(binder.ctx, self.value);
            }
        }
    };
}
