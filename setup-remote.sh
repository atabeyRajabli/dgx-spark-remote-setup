#!/usr/bin/env bash
# ==================================================================
#  DGX Spark remote-access setup
# ==================================================================
#
#  WHAT THIS DOES
#  Gets the Spark ready so you can control it from your laptop with
#  RustDesk, even when nobody is sitting in front of it.
#
#    Step 1. Backs up the login settings file (safety copy)
#    Step 2. Turns off Wayland      -> removes RustDesk's pink warning
#    Step 3. Turns on auto-login    -> after a reboot the Spark goes
#                                      straight to the desktop
#    Step 4. Turns off sleep + lock -> the Spark always stays reachable
#    Step 5. Sets up RustDesk       -> starts on boot, permanent password
#
#  HOW TO RUN IT (on the Spark, in Terminal)
#  Replace PickAPassword with the password you want to type on your
#  laptop when connecting with RustDesk:
#
#    curl -fsSL https://raw.githubusercontent.com/atabeyRajabli/dgx-spark-remote-setup/main/setup-remote.sh | bash -s -- 'PickAPassword'
#
#  Then reboot:   sudo reboot
#
#  UNDO
#  The original login settings are saved at /etc/gdm3/custom.conf.bak
#  To restore:    sudo cp /etc/gdm3/custom.conf.bak /etc/gdm3/custom.conf
# ==================================================================

set -e                                   # stop if any step fails

LOGIN_SETTINGS=/etc/gdm3/custom.conf     # file that controls the login screen
MY_USER="${SUDO_USER:-$USER}"            # the Ubuntu user to auto-login (e.g. sal)
RUSTDESK_PASSWORD="$1"                   # the password you typed after the command

say() { echo; echo ">>> $1"; }           # prints a step heading


# ---- Step 1: safety copy -----------------------------------------
say "Step 1/5: Saving a backup of the login settings"
sudo cp "$LOGIN_SETTINGS" "$LOGIN_SETTINGS.bak"
echo "    Saved to $LOGIN_SETTINGS.bak"


# ---- Step 2: turn off Wayland ------------------------------------
# RustDesk can't be controlled remotely on Wayland without someone
# clicking "Allow" on the Spark. Xorg doesn't have that problem.
say "Step 2/5: Turning off Wayland"
sudo sed -i 's/^#\s*WaylandEnable=false/WaylandEnable=false/' "$LOGIN_SETTINGS"
if ! grep -q '^WaylandEnable=false' "$LOGIN_SETTINGS"; then
  sudo sed -i '/^\[daemon\]/a WaylandEnable=false' "$LOGIN_SETTINGS"
fi
echo "    Done"


# ---- Step 3: turn on automatic login -----------------------------
# Without this, after a reboot the Spark waits at the password screen
# and RustDesk can't show you the desktop.
say "Step 3/5: Turning on automatic login for '$MY_USER'"
sudo sed -i '/^#\?\s*AutomaticLoginEnable\s*=/d' "$LOGIN_SETTINGS"   # remove old lines
sudo sed -i '/^#\?\s*AutomaticLogin\s*=/d'       "$LOGIN_SETTINGS"
sudo sed -i "/^\[daemon\]/a AutomaticLoginEnable=true\nAutomaticLogin=$MY_USER" "$LOGIN_SETTINGS"
echo "    Done"


# ---- Step 4: never sleep, never lock -----------------------------
say "Step 4/5: Turning off sleep, screen blanking and screen lock"
gsettings set org.gnome.desktop.session idle-delay 0                                  || true  # never blank screen
gsettings set org.gnome.desktop.screensaver lock-enabled false                        || true  # never lock
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' || true  # never sleep
echo "    Done"


# ---- Step 5: RustDesk --------------------------------------------
say "Step 5/5: Setting up RustDesk"
if command -v rustdesk >/dev/null 2>&1; then
  sudo systemctl enable --now rustdesk || true      # start RustDesk on every boot
  echo "    RustDesk will start automatically on boot"

  if [ -n "$RUSTDESK_PASSWORD" ]; then
    if sudo rustdesk --password "$RUSTDESK_PASSWORD"; then
      echo "    Permanent password set"
    else
      echo "    Couldn't set the password here. Set it in RustDesk > Settings > Security"
    fi
  else
    echo "    No password given. Set one in RustDesk > Settings > Security"
  fi

  RUSTDESK_ID="$(rustdesk --get-id 2>/dev/null || true)"
else
  echo "    RustDesk isn't installed yet. Install it first, then run this again."
fi


# ---- Summary -----------------------------------------------------
echo
echo "=================================================================="
echo "  ALL DONE"
echo "=================================================================="
echo "  RustDesk ID : ${RUSTDESK_ID:-open RustDesk on the Spark to see it}"
echo "  Password    : the one you typed after the command"
echo
echo "  NEXT: reboot the Spark by typing:   sudo reboot"
echo "  Then on your laptop: open RustDesk, enter the ID, click Connect."
echo "=================================================================="
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
