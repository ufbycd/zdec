const std = @import("std");

pub const lv = @import("zlvgl");
pub const Property = @import("property.zig").Property;

pub const Id = enum(i16) {
    Obj,
    Screen,
    Button,
    Label,
    Line,
    Checkbox,
    Bar,
    Arc,
    Switch,
    Slider,
    TabView,
    List,
    Table,
    Canvas,
    Anim,
    Dropdown,
    Flex,
    //     Window,
};

const Error = error{
    SyntaxError,
    MissMatchCallback,
    NoAttribute,
};

pub const Pos = struct {
    x: i16 = 0,
    y: i16 = 0,

    fn apply(self: @This(), widget: anytype) !void {
        widget.setPos(self.x, self.y);
    }
};

pub const Size = struct {
    width: i16 = 100,
    height: i16 = 100,

    fn apply(self: @This(), widget: anytype) !void {
        widget.setSize(self.width, self.height);
    }
};

pub const Align = struct {
    lv_align: lv.Align = .Default,
    x_ofs: lv.Coord = 0,
    y_ofs: lv.Coord = 0,

    fn apply(self: Align, widget: anytype) !void {
        widget.setAlign(self.lv_align, self.x_ofs, self.y_ofs);
    }
};

pub const BitAction = enum {
    Add,
    Clear,
};

pub const Flags = struct {
    action: BitAction = .Add,
    flags: u32 = 0,
};

pub const States = struct {
    action: BitAction = .Add,
    states: u16 = 0,
};

pub const Font = struct {
    size: u8 = 16,
};

pub const Text = struct {
    text: [:0]const u8 = "",
    font: Font = .{},

    fn apply(self: @This(), widget: anytype) !void {
        widget.setText(self.text);
    }
};

pub const Label = struct {
    text: [:0]const u8 = "",
    alignment: Align = .{ .lv_align = .Center },
    font: Font = .{},

    fn apply(self: Label, widget: anytype) !void {
        const label = lv.Label.init(widget);
        label.setText(self.text);
        self.alignment.apply(label);
    }
};

pub const Range = struct {
    min: i32 = 0,
    max: i32 = 100,
    default: i32 = 0,

    fn apply(self: Range, widget: anytype) !void {
        const Widget = @TypeOf(widget);
        if (!@hasDecl(Widget, "setRange")) {
            @compileError(@typeName(Widget) ++ " does not have 'Range' attribute!");
            // return Error.NoAttribute;
        }

        widget.setRange(self.min, self.max);
        if (@TypeOf(widget) == lv.Slider) {
            widget.setValue(self.default, lv.AnimEnable.On);
        } else {
            widget.setValue(self.default);
        }
    }
};

pub const BindingType = enum {
    Value,
    Text,
    Pos,
    Size,
    Align,
    Style,
    States,
    Flags,

    fn DataType(comptime self: BindingType) type {
        return switch (self) {
            .Value => i32,
            .Text => ?[:0]u8,
            .Pos => Pos,
            .Size => Size,
            .Align => Align,
            else => unreachable,
        };
    }
};

fn BindingInfo(comptime binding_type: BindingType, comptime PropertyType: type) type {
    const ValueType = PropertyType.ValueType;
    return struct {
        allocator: std.mem.Allocator,
        property: ?*PropertyType,
        nativeObj: ?*lv.c.lv_obj_t,
        to_view: ?*const fn (alloc: std.mem.Allocator, value: ValueType) binding_type.DataType() = null,
        to_mode: ?*const fn (alloc: std.mem.Allocator, mode_data: binding_type.DataType()) ValueType = null,
    };
}

fn isBind(comptime T: type) bool {
    return std.mem.startsWith(u8, @typeName(T), "zdec.Bind(");
}

pub fn Bind(comptime binding_type: BindingType, comptime PropertyType: type, comptime format: ?[]const u8) type {
    const ValueType = PropertyType.ValueType;
    return struct {
        binding_type: BindingType = binding_type,
        property: *PropertyType,
        allocator: std.mem.Allocator = undefined,
        to_view: ?*const fn (alloc: std.mem.Allocator, prop_value: ValueType) binding_type.DataType() = if (format) |fmt|
            struct {
                fn f(alloc: std.mem.Allocator, value: ValueType) ?[:0]u8 {
                    return std.fmt.allocPrintZ(alloc, fmt, .{value}) catch null;
                }
            }.f
        else
            null,
        to_mode: ?*const fn (alloc: std.mem.Allocator, mode_data: binding_type.DataType()) ValueType = null,

        const Self = @This();

        pub fn init(self: Self) Self {
            // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
            var bind = self;
            // bind.allocator = gpa.allocator();
            bind.allocator = std.heap.c_allocator;
            return bind;
        }

        pub fn apply(self: Self, widget: anytype) !void {
            const Widget = @TypeOf(widget);
            // const NativeObj = @TypeOf(widget.obj);
            var bind_id: u32 = PropertyType.InvalidBindId;
            var widgetEventCallbackAdded = false;
            const TheBindingInfo = BindingInfo(binding_type, PropertyType);
            var binding_info = try self.allocator.create(TheBindingInfo);
            binding_info.allocator = self.allocator;
            binding_info.property = self.property;
            binding_info.nativeObj = widget.obj;
            binding_info.to_view = self.to_view;

            std.debug.print("Bind: {s} to {s}\n", .{ @typeName(@TypeOf(self.property)), @typeName(@TypeOf(widget)) });
            switch (self.binding_type) {
                .Value => {
                    if (@hasDecl(Widget, "setValue")) {
                        widget.setValue(self.property.getValue(), lv.AnimEnable.Off); // init widget's value from property
                        bind_id = try self.property.bind(binding_info, struct {
                            pub fn onValueChanged(the_binding_info: *TheBindingInfo, value: ValueType) void {
                                if (the_binding_info.nativeObj) |obj| {
                                    const the_widget = Widget{ .obj = obj };
                                    the_widget.setValue(value, lv.AnimEnable.On);
                                }
                            }
                        });

                        widgetEventCallbackAdded = widget.addEventCallbacks(binding_info, struct {
                            pub fn onValueChanged(event: anytype) void {
                                const the_binding_info = event.getUserData();
                                if (the_binding_info.property) |prop| {
                                    const value = event.getTarget().getValue();
                                    std.debug.print("{s} value: {}\n", .{ @typeName(@TypeOf(event.getTarget())), value });
                                    _ = prop.setValue(value);
                                }
                            }
                        }) > 0;
                    }
                },

                .Text => {
                    if (@hasDecl(Widget, "setText")) {
                        // init widget's text from property
                        if (self.to_view) |to_view| {
                            const text = to_view(self.allocator, self.property.value);
                            if (text) |t| {
                                defer self.allocator.free(t);
                                widget.setText(t);
                            }
                        }
                        // else if (self.format) |fmt| {
                        //     const text = std.fmt.allocPrintZ(self.allocator, fmt, .{self.property.value}) catch unreachable;

                        //     defer self.allocator.free(text);
                        //     widget.setText(text);
                        // }

                        bind_id = try self.property.bind(binding_info, struct {
                            pub fn onValueChanged(the_binding_info: *TheBindingInfo, value: ValueType) void {
                                if (the_binding_info.nativeObj) |obj| {
                                    const the_widget = Widget{ .obj = obj };
                                    if (the_binding_info.to_view) |to_view| {
                                        const text = to_view(the_binding_info.allocator, value);
                                        if (text) |t| {
                                            the_widget.setText(t);
                                            the_binding_info.allocator.free(t);
                                        }
                                    }
                                }
                            }
                        });
                    }
                },
                else => {
                    return Error.SyntaxError;
                },
            }

            if (bind_id != PropertyType.InvalidBindId) {
                _ = widget.addEventCallback(binding_info, struct {
                    pub fn onDelete(event: anytype) void {
                        // unbind widget to property
                        var the_binding_info: *TheBindingInfo = event.getUserData();
                        if (the_binding_info.property) |prop| {
                            prop.unbind(the_binding_info);
                            the_binding_info.nativeObj = null;
                        }

                        the_binding_info.allocator.destroy(the_binding_info);
                    }
                });
            }
        }
    };
}

fn WidgetType(comptime id: Id) type {
    return switch (id) {
        .Button => lv.Button,
        .Label => lv.Label,
        .Line => lv.Line,
        .Checkbox => lv.Checkbox,
        .Bar => lv.Bar,
        .Arc => lv.Arc,
        .Switch => lv.Switch,
        .Slider => lv.Slider,
        .TabView => lv.TabView,
        .List => lv.List,
        .Table => lv.Table,
        .Canvas => lv.Canvas,
        .Anim => lv.Anim,
        .Dropdown => lv.Dropdown,
        .Flex => lv.Flex,
        //         .Window => lv.Window,
        else => lv.Obj,
    };
}

pub fn buildWidget(parent: anytype, item: anytype) !WidgetType(item[0]) {
    const Widget = WidgetType(item[0]);
    const widget = Widget.init(parent);
    //     std.debug.print("build {s}\n", .{@typeName(Widget)});
    inline for (item) |field| {
        const T = @TypeOf(field);
        switch (T) {
            Id => {},
            type => {
                const count = widget.addEventCallbacks(null, field);
                if (count == 0) {
                    return Error.MissMatchCallback;
                }
            },
            Text => {
                if (Widget == lv.Button and widget.getChildCnt() == 0) {
                    const label = lv.Label.init(widget);
                    label.center();
                }

                try field.apply(widget);
            },
            Pos, Size, Align, Label, Range => try field.apply(widget),
            else => {
                std.debug.print("field type: {s}\n", .{@typeName(T)});
                if (std.meta.trait.is(.Fn)(@TypeOf(field))) {
                    std.debug.print("{}\n", .{@TypeOf(field)});
                } else if (comptime isBind(T)) {
                    var bind = field.init();
                    try bind.apply(widget);
                } else if (@hasField(T, "user_data")) {
                    const count = widget.addEventCallbacks(field.user_data, T);
                    if (count == 0) {
                        return Error.MissMatchCallback;
                    }
                } else if (std.meta.trait.isTuple(field)) {
                    _ = buildUI(widget, field);
                } else {
                    return Error.SyntaxError;
                }
            },
        }
    }

    return widget;
}

pub fn bindWidget(widget: anytype, bind_info: anytype) !void {
    _ = bind_info;
    _ = widget;
}

pub fn buildUI(parent: anytype, items: anytype) !lv.Obj {
    var root: ?lv.Obj = null;

    inline for (items) |item| {
        const T = @TypeOf(item[0]);
        switch (T) {
            Id => {
                const widget = try buildWidget(parent, item);
                if (root == null) {
                    root = widget.asObj();
                }
            },
            else => {
                const obj = try buildUI(parent, item);
                if (root == null) {
                    root = obj;
                }
            },
        }
    }

    if (root) |obj| {
        return obj;
    } else {
        return Error.SyntaxError;
    }
}
