# zdec - Declarative UI Framework

## Code Example

```zig
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

    _ = try d.buildUI(lv.Screen.active(), main_ui);
```

## Run Example

zlvgl and zdev are both hosted on github.com and gitee.com

```
$ git clone https://github.com/ufbycd/zlvgl.git
$ git clone https://github.com/ufbycd/zdec.git
```
or
```
$ git clone https://github.com/ufbycd/zlvgl.git
$ git clone https://github.com/ufbycd/zdec.git
```
then build and run
```
$ cd zdec
$ zig build run
```