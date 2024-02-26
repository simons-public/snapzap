# snapzap

```diff
- snapzap is beta software
```

`snapzap` is a command-line utility for listing and pruning ZFS snapshots with ease and efficiency. Unlike traditional methods that rely on calling external `zfs` and `zpool` commands, snapzap leverages the libzfs library directly.

I built this because I didn't feel comfortable with the fact that the `zfs destroy` command has no way of filtering zfs types for destruction. This makes scripting a bit dangerous, with so many possible footguns that could cause the wrong arguments to get passed to the command and result in data loss.

Key Features:
- **Snapshot Management:** snapzap provides a streamlined interface for listing, filtering, and deleting ZFS snapshots that works well for automation with cronjobs or systemd timers.
- **Direct Integration with ZFS:** By utilizing the libzfs library, snapzap offers direct integration with ZFS, eliminating the need for intermediate shell commands or risky `grep` or `xargs` mistakes.
- **Safe and Reliable:** snapzap ensures the safe deletion of snapshots, guarding against accidental deletion of critical datasets by only calling libzfs functions that delete snapshots or using zfs handles directly.
- **Does not filter by snapshot names:** Filters can be guids, creation dates, even user properties (custom properties containing `:`). Not filtering by snapshot names is an intentional design choice.

`snapzap` aims to simplify ZFS snapshot pruning without the possiblility of deleting datasets.

## Building:

`snapzap` requires libzfs and libspl (typically included with zfs-utils). Use `make` to use the included Makefile to build with `cmake` and `make install` with elevated privileges to install. If `cmake` isn't installed, it can be compiled with `make snapzap` instead.
Other Makefile targets include `clean`, `check` (using cppcheck), and `tidy` (using clang-format and clang-tidy).

## Examples:

Example systemd scripts are included in the examples directory for daily and weekly systemd timers and services.
