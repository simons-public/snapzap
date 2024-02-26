# snapzap

$${\color{red}snapzap is beta software}$$

snapzap is a command-line utility for listing and pruning ZFS snapshots with ease and efficiency. Unlike traditional methods that rely on calling external `zfs` and `zpool` commands, snapzap leverages the `libzfs` library directly.

## Key Features:
- **Efficient Snapshot Management:** snapzap provides a streamlined interface for listing, filtering, and deleting ZFS snapshots that works well for automation with cronjobs or systemd timers.
- **Direct Integration with ZFS:** By utilizing the `libzfs` library, snapzap offers direct integration with ZFS, eliminating the need for intermediate shell commands or risky `grep` or `xargs` mistakes.
- **Safe and Reliable:** snapzap ensures the safe deletion of snapshots, guarding against accidental deletion of critical datasets by only calling libzfs functions that delete snapshots or using zfs handles directly.

snapzap aims to simplify ZFS snapshot pruning without the possiblility of deleting datasets. 
