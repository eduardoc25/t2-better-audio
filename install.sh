#!/usr/bin/env sh

set -eu

# This script must be run as a normal user as it needs to read the XDG_CONFIG_HOME variable.

script_path=$(dirname -- "$0")
script_dir=$(CDPATH='' cd -- "$script_path" && pwd)

if [ "$(id -u)" -ne 0 ]
then
    echo This script must be run as root, you will be prompted for your password
    exec sudo env T2_BETTER_AUDIO_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" sh "$script_dir/install.sh"
fi

config_home=${T2_BETTER_AUDIO_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}
source_dir="$script_dir/files"

for file in \
    profile-sets/apple-t2x2.conf \
    profile-sets/apple-t2x4.conf \
    profile-sets/apple-t2x6.conf \
    paths/t2-builtin-mic.conf \
    paths/t2-headphones.conf \
    paths/t2-headset-mic.conf \
    paths/t2-speakers.conf \
    91-audio-custom.rules
do
    if [ ! -f "$source_dir/$file" ]
    then
        echo "Missing source file: $source_dir/$file" >&2
        exit 1
    fi
done

delete_choice=

for file in "/usr/share/pulseaudio/alsa-mixer/profile-sets/apple-t2x2.conf" \
            "/usr/share/pulseaudio/alsa-mixer/profile-sets/apple-t2x4.conf" \
            "/usr/share/pulseaudio/alsa-mixer/profile-sets/apple-t2x6.conf" \
            "/usr/share/pulseaudio/alsa-mixer/profile-sets/apple-t2.conf" \
            "/usr/share/alsa-card-profile/mixer/profile-sets/apple-t2x2.conf" \
            "/usr/share/alsa-card-profile/mixer/profile-sets/apple-t2x4.conf" \
            "/usr/share/alsa-card-profile/mixer/profile-sets/apple-t2x6.conf" \
            "/usr/share/alsa-card-profile/mixer/profile-sets/apple-t2.conf" \
            "/usr/lib/udev/rules.d/91-pulseaudio-custom.rules" \
            "/usr/lib/udev/rules.d/91-audio-custom.rules" \
            "/usr/share/alsa/cards/AppleT2.conf"
do
    if [ -f "$file" ]
    then
        if [ -z "$delete_choice" ]
        then
            printf 'Old configuration files are present, do you want to delete them? (y/n) '
            IFS= read -r delete_choice

            if [ "$delete_choice" != "y" ]
            then
                break
            fi
        fi

        rm -v "$file"
    fi
done

for file in "$config_home/pulse/default.pa" \
            "$config_home/pulse/daemon.conf" \
            "$config_home/pipewire/pipewire.conf.d" \
            "$config_home/wireplumber/wireplumber.conf.d"
do
    if [ -e "$file" ]
    then
        echo "You seem to have audio configuration files present, don't forget to update them if they contain anything specific to T2 Macs"
        break
    fi
done

installed_dirs=0

for dir in "/usr/share/alsa-card-profile/mixer" "/usr/share/pulseaudio/alsa-mixer"
do
    if [ -d "$dir" ]
    then
        cp -rv "$source_dir/profile-sets" "$dir"
        cp -rv "$source_dir/paths" "$dir"
        installed_dirs=$((installed_dirs + 1))
    fi
done

if [ "$installed_dirs" -eq 0 ]
then
    echo "No supported ALSA card profile directory was found under /usr/share." >&2
    echo "This system may not have PipeWire or PulseAudio ACP support installed." >&2
    exit 1
fi

cp -v "$source_dir/91-audio-custom.rules" /usr/lib/udev/rules.d/

for dir in "/usr/share/alsa-card-profile/mixer" "/usr/share/pulseaudio/alsa-mixer"
do
    if [ -d "$dir" ]
    then
        for file in \
            profile-sets/apple-t2x2.conf \
            profile-sets/apple-t2x4.conf \
            profile-sets/apple-t2x6.conf \
            paths/t2-builtin-mic.conf \
            paths/t2-headphones.conf \
            paths/t2-headset-mic.conf \
            paths/t2-speakers.conf
        do
            if [ ! -f "$dir/$file" ]
            then
                echo "Installation verification failed: missing $dir/$file" >&2
                exit 1
            fi
        done
    fi
done

if [ ! -f /usr/lib/udev/rules.d/91-audio-custom.rules ]
then
    echo "Installation verification failed: missing /usr/lib/udev/rules.d/91-audio-custom.rules" >&2
    exit 1
fi

check_pipewire_session() {
    if [ -z "${SUDO_USER:-}" ]
    then
        echo "Skipping PipeWire/WirePlumber session check because no invoking user was detected."
        return 0
    fi

    if ! command -v pgrep >/dev/null 2>&1
    then
        echo "Skipping PipeWire/WirePlumber session check because pgrep is not available."
        return 0
    fi

    user_uid=$(id -u "$SUDO_USER")
    pipewire_running=0
    wireplumber_running=0

    if pgrep -u "$user_uid" -x pipewire >/dev/null 2>&1
    then
        pipewire_running=1
    fi

    if pgrep -u "$user_uid" -x wireplumber >/dev/null 2>&1
    then
        wireplumber_running=1
    fi

    if [ "$pipewire_running" -eq 1 ] && [ "$wireplumber_running" -eq 1 ]
    then
        echo "PipeWire and WirePlumber appear to be running for $SUDO_USER."
    else
        echo "PipeWire and/or WirePlumber were not detected for $SUDO_USER."
    fi

    if command -v pactl >/dev/null 2>&1
    then
        if pactl info 2>/dev/null | grep -q 'Server Name: PulseAudio (on PipeWire'
        then
            echo "pactl confirms PulseAudio is running on PipeWire."
        else
            echo "pactl did not confirm a PipeWire-backed PulseAudio server."
        fi
    else
        echo "Skipping pactl bridge check because pactl is not available."
    fi

    echo "To reload the session services, run:"
    echo "  systemctl --user restart wireplumber pipewire"
    echo "To verify audio after reloading, run:"
    echo "  wpctl status"
    echo "  pactl info"
}

printf 'Run an optional PipeWire/WirePlumber check now? (y/n) '
IFS= read -r run_post_install_check
if [ "$run_post_install_check" = "y" ]
then
    check_pipewire_session
fi

echo "Installation completed successfully."
