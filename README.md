# Better Audio for Macs with the T2 Chip

Currently, someone who wants to run linux on their T2 Mac must install the audio files manually depending on their model and things like switching to headphones when plugging them automatically does not work, so the situation is less than ideal. Coupled with changes made in `apple-bce`, this repository tries to improve this situation. Modern distros usually run `pipewire`, and the installer places the profiles in the ALSA card profile directories that PipeWire uses. `pulseaudio` is still supported, but `pipewire` will usually work better.

Note that an `apple-bce` with [these changes made](https://github.com/kekrby/apple-bce) is required.

The files are based on `https://gist.github.com/MCMrARM/c357291e4e5c18894bea10665dcebffb`, `https://gist.github.com/kevineinarsson/8e5e92664f97508277fefef1b8015fba`, `https://gist.github.com/bigbadmonster17/8b670ae29e0b7be2b73887f3f37a057b` and `https://github.com/Redecorating/archlinux-t2-packages/tree/main/apple-t2-audio-config`.

## Installation
You can install the files using `install.sh`.

The installer copies the profile sets and path definitions into the system `alsa-card-profile` directory, which is what PipeWire reads on current distros, and also keeps compatibility with older PulseAudio layouts when they are present.

At the end of the install, the script can optionally check whether `pipewire` and `wireplumber` are running for the current user. If `pactl` is available, it also confirms that the session is using PulseAudio on top of PipeWire. If `pactl` is not installed, that extra bridge check is skipped and the installation still completes normally.

When the optional check runs, the script prints the commands you can use to reload and test the session:

- `systemctl --user restart wireplumber pipewire`
- `wpctl status`
- `pactl info` when available

Note that some distributions (for example NixOS) may have different ways to install the files.
