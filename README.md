# null_motor

A Player driver plugin that provides one or more "motor" interfaces and
silently discards every command sent to them. Used to neuter the vacuum,
main-brush, and side-brush motor channels on a Rockrobo/Roborock S5 gen1
without touching anything else the chassis driver provides (odometry,
bumper, cliff, gyro, power, ...).

Built against the robot's own `libplayercore.so`/`libplayerinterface.so`/
`libplayercommon.so` (cross-compiled armhf, matching the robot's glibc
2.19 + libstdc++ 4.8 ABI) -- see `build.sh`.

## Why this exists

`ruby_chassis.cfg`'s `ruby_chassis` driver block `provides` the real motor
channels (`"vaccuum:::motor:0" "main:::motor:1" "right:::motor:2"`, among
everything else), and `DriverTest` (`libNavDriver`) `requires` them.
Deleting those entries from either side segfaults `player`, because
`DriverTest` never null-checks a failed `requires` lookup.

`null_motor` lets you swap out *only* the real motor provider without
touching `DriverTest`'s `requires` line at all: re-index the real
`ruby_chassis` motor entries to unused numbers, then have `null_motor`
provide the original `motor:0/1/2` addresses instead. `DriverTest` binds
exactly as before -- it just never gets a physical response.

## Building

```
./build.sh
```

Needs Docker and a copy of the robot's own `libplayercore.so`,
`libplayerinterface.so`, and `libplayercommon.so` in `reflib/` (copy them
from `/opt/rockrobo/cleaner/lib/` on the robot first). Produces
`out/libnullmotor.so`.

## Deploying (not done by this project -- wire up by hand)

1. Copy `libnullmotor.so` to `/opt/rockrobo/cleaner/lib/` on the robot.
2. In `/opt/rockrobo/cleaner/conf/ruby_chassis.cfg`, re-index the real
   motor entries in the `ruby_chassis` driver's `provides` list:

   ```
   "vaccuum:::motor:0" "main:::motor:1" "right:::motor:2"
   ```
   becomes
   ```
   "vaccuum:::motor:10" "main:::motor:11" "right:::motor:12"
   ```

3. Add a new driver block anywhere in the same file (order doesn't
   matter -- Player resolves `requires`/`provides` by address, not file
   position):

   ```
   driver
   (
     name "null_motor"
     plugin "/opt/rockrobo/cleaner/lib/libnullmotor.so"
     provides ["motor:0" "motor:1" "motor:2"]
     verbose 1   # log each discarded command to player's own log; set 0 to silence
   )
   ```

   Use the **full path** here, not a bare `plugin "libnullmotor"`. Every
   vendor plugin (`libchassisdriver`, etc.) loads fine by bare name only
   because it's registered in the robot's `ldconfig` cache
   (`ldconfig -p | grep libplayercore` shows the whole vendor set);
   `libnullmotor.so` isn't in that cache since it was added after the
   last `ldconfig` run, so a bare-name `dlopen()` can't find it at all --
   `player` prints `connect success!` and then just exits, no error.
   Confirmed on hardware: full path loads and stays resident; bare name
   silently doesn't, with or without `LD_LIBRARY_PATH` set. Full path
   sidesteps the problem entirely without needing to run `ldconfig`
   (which would touch shared system state) -- the plugin's own
   dependencies (`libplayercore.so` etc.) still resolve fine via the
   existing cache once it's actually been opened.

4. `DriverTest`'s own `requires` line is untouched -- it still says
   `"vaccuum:::motor:0" "main:::motor:1" "right:::motor:2"`, which now
   resolves to `null_motor` instead of the real chassis driver.

Test by hand-launching a second `player` against a copy of the cfg first
(`player /path/to/test-ruby_chassis.cfg`) rather than pointing the live
boot cfg at it directly -- if `player` fails to start at all, a reboot
reverts to the original, unmodified cfg.
