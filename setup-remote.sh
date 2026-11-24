#!/usr/bin/env bash
# DGX Spark: prepare for unattended remote access (RustDesk / Remote Desktop)
#  - switches the login screen to Xorg (RustDesk can't do unattended access on Wayland)
#  - enables automatic login for the current user
#  - turns off screen blanking, auto-suspend and screen lock
#  - optionally sets a permanent RustDesk password
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/atabeyRajabli/dgx-spark-remote-setup/main/setup-remote.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/atabeyRajabli/dgx-spark-remote-setup/main/setup-remote.sh | bash -s -- 'YourRustDeskPassword'
set -e

CONF=/etc/gdm3/custom.conf
ME="${SUDO_USER:-$USER}"
RD_PASS="$1"

echo "==> Backing up $CONF to $CONF.bak"
sudo cp "$CONF" "$CONF.bak"

echo "==> Disabling Wayland (use Xorg)"
sudo sed -i 's/^#\s*WaylandEnable=false/WaylandEnable=false/' "$CONF"
grep -q '^WaylandEnable=false' "$CONF" || sudo sed -i '/^\[daemon\]/a WaylandEnable=false' "$CONF"

echo "==> Enabling automatic login for $ME"
sudo sed -i '/^#\?\s*AutomaticLoginEnable\s*=/d;/^#\?\s*AutomaticLogin\s*=/d' "$CONF"
sudo sed -i "/^\[daemon\]/a AutomaticLoginEnable=true\nAutomaticLogin=$ME" "$CONF"

echo "==> Turning off screen blank, auto-suspend and screen lock"
gsettings set org.gnome.desktop.session idle-delay 0 || true
gsettings set org.gnome.desktop.screensaver lock-enabled false || true
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' || true
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' || true

if command -v rustdesk >/dev/null 2>&1; then
  echo "==> Making sure the RustDesk service starts on boot"
  sudo systemctl enable --now rustdesk || true
  if [ -n "$RD_PASS" ]; then
    echo "==> Setting permanent RustDesk password"
    sudo rustdesk --password "$RD_PASS" || echo "   (couldn't set it from the command line; set it in RustDesk > Settings > Security)"
  fi
  echo "==> RustDesk ID: $(rustdesk --get-id 2>/dev/null || echo 'open RustDesk to see it')"
fi

echo
echo "==> [daemon] section of $CONF now reads:"
grep -A4 '^\[daemon\]' "$CONF"
echo
echo "Done. Reboot to apply:  sudo reboot"
