#!/bin/sh

set -eu

. ./lib.sh

PROGNAME=$(basename "$0")
ARCH=$(uname -m)
IMAGES="base"
TRIPLET=
REPO=
DATE=$(date -u +%Y%m%d)

usage() {
	cat <<-EOH
	Usage: $PROGNAME [options ...] [-- mklive options ...]

	Wrapper script around mklive.sh for several standard flavors of live images.
	Adds system-installer and other helpful utilities to the generated images.

	OPTIONS
	 -a <arch>     Set XBPS_ARCH in the image
	 -b <variant>  One of base, standard, lite (default: base). May be specified multiple times
	               to build multiple variants
	 -d <date>     Override the datestamp on the generated image (YYYYMMDD format)
	 -t <arch-date-variant>
	               Equivalent to setting -a, -b, and -d
	 -r <repo>     Use this XBPS repository. May be specified multiple times
	 -h            Show this help and exit
	 -V            Show version and exit

	Other options can be passed directly to mklive.sh by specifying them after the --.
	See mklive.sh -h for more details.
	EOH
}

while getopts "a:b:d:t:hr:V" opt; do
case $opt in
    a) ARCH="$OPTARG";;
    b) IMAGES="$OPTARG";;
    d) DATE="$OPTARG";;
    r) REPO="-r $OPTARG $REPO";;
    t) TRIPLET="$OPTARG";;
    V) version; exit 0;;
    h) usage; exit 0;;
    *) usage >&2; exit 1;;
esac
done
shift $((OPTIND - 1))

INCLUDEDIR=$(mktemp -d)
trap "cleanup" INT TERM

cleanup() {
    rm -rf "$INCLUDEDIR"
}

setup_pipewire() {
    PKGS="$PKGS pipewire alsa-pipewire"
    mkdir -p "$INCLUDEDIR"/etc/xdg/autostart
    ln -sf /usr/share/applications/pipewire.desktop "$INCLUDEDIR"/etc/xdg/autostart/
    mkdir -p "$INCLUDEDIR"/etc/pipewire/pipewire.conf.d
    ln -sf /usr/share/examples/wireplumber/10-wireplumber.conf "$INCLUDEDIR"/etc/pipewire/pipewire.conf.d/
    ln -sf /usr/share/examples/pipewire/20-pipewire-pulse.conf "$INCLUDEDIR"/etc/pipewire/pipewire.conf.d/
    mkdir -p "$INCLUDEDIR"/etc/alsa/conf.d
    ln -sf /usr/share/alsa/alsa.conf.d/50-pipewire.conf "$INCLUDEDIR"/etc/alsa/conf.d
    ln -sf /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf "$INCLUDEDIR"/etc/alsa/conf.d
}

build_variant() {
    variant="$1"
    shift
    IMG=aurumOS-${variant}-${ARCH}-${DATE}.iso
    GRUB_PKGS="grub-i386-efi grub-x86_64-efi"
    A11Y_PKGS="espeakup void-live-audio brltty"
    PKGS="dialog cryptsetup lvm2 mdadm void-docs-browse xtools-minimal xmirror chrony nix $A11Y_PKGS $GRUB_PKGS"
    XORG_PKGS="xorg-minimal xorg-input-drivers xorg-video-drivers setxkbmap xauth font-misc-misc terminus-font dejavu-fonts-ttf orca"
    SERVICES="sshd chronyd nix-daemon"

    LIGHTDM_SESSION=''

    case $variant in
        base)
            SERVICES="$SERVICES dhcpcd wpa_supplicant acpid"
        ;;
        standard)
            PKGS="$PKGS $XORG_PKGS lightdm lightdm-gtk3-greeter budgie-desktop gnome-keyring colord gnome-terminal nautilus gvfs-afc gvfs-mtp gvfs-smb udisks2 firefox vlc libreoffice"
            SERVICES="$SERVICES dbus lightdm NetworkManager polkitd"
            LIGHTDM_SESSION=budgie
        ;;
	lite)
            PKGS="$PKGS $XORG_PKGS lightdm lightdm-gtk3-greeter budgie-desktop gnome-keyring colord gnome-terminal nautilus gvfs-afc gvfs-mtp gvfs-smb udisks2 firefox vlc"
            SERVICES="$SERVICES dbus lightdm NetworkManager polkitd"
            LIGHTDM_SESSION=budgie
        ;;
        *)
            >&2 echo "Unknown variant $variant"
            exit 1
        ;;
    esac

    if [ -n "$LIGHTDM_SESSION" ]; then
        mkdir -p "$INCLUDEDIR"/etc/lightdm
        echo "$LIGHTDM_SESSION" > "$INCLUDEDIR"/etc/lightdm/.session
        # needed to show the keyboard layout menu on the login screen
        cat <<- EOF > "$INCLUDEDIR"/etc/lightdm/lightdm-gtk-greeter.conf
[greeter]
indicators = ~host;~spacer;~clock;~spacer;~layout;~session;~a11y;~power
EOF
    fi

    if [ "$variant" != base ]; then
        setup_pipewire
    fi

    ./mklive.sh -a "$ARCH" -o "$IMG" -p "$PKGS" -S "$SERVICES" -I "$INCLUDEDIR" ${REPO} "$@"

	cleanup
}

if [ ! -x mklive.sh ]; then
    echo mklive.sh not found >&2
    exit 1
fi

if [ -x installer.sh ]; then
    MKLIVE_VERSION="$(PROGNAME='' version)"
    installer=$(mktemp)
    sed "s/@@MKLIVE_VERSION@@/${MKLIVE_VERSION}/" installer.sh > "$installer"
    install -Dm755 "$installer" "$INCLUDEDIR"/usr/bin/system-installer
    rm "$installer"
else
    echo installer.sh not found >&2
    exit 1
fi

if [ -n "$TRIPLET" ]; then
    VARIANT="${TRIPLET##*-}"
    REST="${TRIPLET%-*}"
    DATE="${REST##*-}"
    ARCH="${REST%-*}"
    build_variant "$VARIANT" "$@"
else
    for image in $IMAGES; do
        build_variant "$image" "$@"
    done
fi
