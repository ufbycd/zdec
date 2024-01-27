const std = @import("std");
const lv = @import("zlvgl");
const d = @import("zdec");

const Model = struct {
    count: d.Property(i32) = .{ .value = 50 },

    const Self = @This();

    pub fn init(self: *Self, allocator: std.mem.Allocator) void {
        self.count.init(allocator);
    }

    pub fn deinit(self: Self) void {
        self.count.deinit();
    }

    pub fn add(self: *Self, step: i32) void {
        var v = self.count.getValue();
        v += step;
        _ = self.count.setValue(v);
        std.debug.print("{s}.add: count {d}\n", .{ @typeName(Self), v });
    }
};

var _step: i32 = 2;

pub fn main() !void {
    lv.init();
    defer lv.deinit();

    lv.drivers.init();
    defer lv.drivers.deinit();
    lv.drivers.register();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();

    var _model = Model{};
    _model.init(allocator);
    defer _model.deinit();

    const main_ui = .{
        .{
            d.Id.Button,
            d.Size{ .width = 160, .height = 48 },
            d.Align{ .lv_align = .Center, .y_ofs = -100 },
            d.Text{ .text = "button" },
            struct {
                user_data: *Model,
                pub fn onClicked(event: anytype) void {
                    const the_model = event.userData();
                    const step = 10;
                    std.debug.print("{s}: add Model.count by {d}\n", .{ @typeName(@TypeOf(event.target())), step });
                    the_model.add(step);
                }
            }{ .user_data = &_model },
        },
        .{
            d.Id.Slider,
            d.Size{ .width = 240, .height = 16 },
            d.Align{ .lv_align = .Center, .y_ofs = 100 },
            d.Range{ .min = 0, .max = 200 },
            d.Bind(d.BindType.Value, @TypeOf(_model.count)){ .property = &_model.count },
        },
    };

    var widget = try d.buildUI(lv.Screen.active(), main_ui);
    _ = widget;

    var lastTick: i64 = std.time.milliTimestamp();
    while (true) {
        const curTick = std.time.milliTimestamp();
        lv.tick.inc(@intCast(curTick - lastTick));
        lastTick = curTick;
        //         lv.task.handler();
        const next_ms = lv.timer.handler();
        std.time.sleep(next_ms * 1_000_000); // sleep 10ms
    }
}
