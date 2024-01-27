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

pub const BindType = enum {
    Value,
    Text,
    Pos,
    Size,
    Align,
    Style,
    States,
    Flags,
};

fn isBind(comptime T: type) bool {
    return std.mem.startsWith(u8, @typeName(T), "zdec.Bind(");
}

pub fn Bind(comptime bind_type: BindType, comptime PropertyType: type) type {
    return struct {
        bind_type: BindType = bind_type,
        property: *PropertyType,

        const Self = @This();

        pub fn init(property: *PropertyType) Self {
            return .{ .property = property };
        }

        pub fn apply(self: Self, widget: anytype) !void {
            const Widget = @TypeOf(widget);
            var bind_id: u32 = PropertyType.InvalidBindId;
            std.debug.print("Bind: {s} to {s}\n", .{ @typeName(@TypeOf(self.property)), @typeName(@TypeOf(widget)) });
            switch (self.bind_type) {
                .Value => {
                    widget.setValue(self.property.getValue(), lv.AnimEnable.Off); // init widget's value from property

                    const Obj = @TypeOf(widget.obj);
                    bind_id = try self.property.bind(widget.obj, struct {
                        pub fn onValueChanged(obj: Obj, value: PropertyType.ValueType) void {
                            const the_widget = Widget{ .obj = obj };
                            the_widget.setValue(value, lv.AnimEnable.On);
                        }
                    });

                    _ = widget.addEventCallback(self.property, struct {
                        pub fn onValueChanged(event: anytype) void {
                            const prop = event.userData();
                            const value = event.target().getValue();
                            std.debug.print("{s} value: {}\n", .{ @typeName(@TypeOf(event.target())), value });
                            prop.update(value);
                        }
                    });
                },

                .Text => {},
                else => {
                    return Error.SyntaxError;
                },
            }

            if (bind_id != PropertyType.InvalidBindId) {
                _ = widget.addEventCallback(self.property, struct {
                    pub fn onDelete(event: anytype) void {
                        // std.debug.print("{s} delete\n", .{@typeName(@TypeOf(event.target()))});
                        // unbind widget to property
                        const prop = event.userData();
                        prop.unbind(event.target().obj);
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
                if (comptime isBind(T)) {
                    try field.apply(widget);
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
