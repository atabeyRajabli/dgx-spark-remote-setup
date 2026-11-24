# DGX Spark: First Boot to Fully Remote (University Lab Setup)

A practical guide for getting an NVIDIA DGX Spark from out-of-the-box to fully remote-controlled from home, written after setting one up in a professor's office at a university (USM). Covers the gotchas we actually hit.

**End state:** the Spark sits in the office, connected to campus Wi-Fi (eduroam) and a monitor the professor can watch. Students control it from their own laptops anywhere: full desktop over Remote Desktop, plus terminal / VS Code / Claude Code.

---

## 1. First boot

### What you need
- A display (HDMI works fine, video only)
- A USB keyboard and mouse
- **A USB-C hub or USB-C to USB-A adapter.** The Spark has **no USB-A ports**, only 4x USB-C on the back (one is used by the power supply). A hub with 2+ USB-A ports lets you plug in both keyboard and mouse.

### Notes
- The monitor's own USB ports do nothing unless the monitor is connected over USB-C. Plug input devices into the Spark directly.
- A laptop **cannot** act as the Spark's monitor (laptop HDMI is output-only) or as its keyboard/mouse over a cable.
- **Headless setup (no keyboard/mouse):** on first boot the Spark broadcasts a Wi-Fi hotspot. The SSID, password and setup URL are on a sticker on the **Quick Start card** in the box. The password is unique per device, so if the card is lost this option is gone. Don't throw it away with the packaging.
- Bluetooth keyboards/mice can pair during setup, but pairing stops once you click "Get Started". Power-cycle to retry.

Complete the setup wizard and create your user account.

---

## 2. Connect to eduroam (USM settings)

USM settings: PEAP / MSCHAPv2, username `w<ID#>@usm.edu`, CampusID password, domain `usm.edu`. Other universities: swap the username format and domain.

### Option A: GUI
1. Network icon (top right) → Wi-Fi → **eduroam**
2. Fill in:
   | Field | Value |
   |---|---|
   | Security | WPA & WPA2 Enterprise |
   | Authentication | Protected EAP (PEAP) |
   | Anonymous identity | *(leave blank)* |
   | Domain | `usm.edu` |
   | CA certificate | (None) / "No CA certificate is required" |
   | PEAP version | Automatic |
   | Inner authentication | MSCHAPv2 |
   | Username | `w1234567@usm.edu` |
   | Password | CampusID password |
3. Connect. Then Settings → Wi-Fi → ⚙️ eduroam → enable **Connect automatically**, and store the password **for all users** (otherwise it may not reconnect after a reboot until someone logs in).

### Option B: one command (recommended for remote machines)
```bash
sudo nmcli connection add type wifi con-name eduroam ssid eduroam -- \
  wifi-sec.key-mgmt wpa-eap 802-1x.eap peap 802-1x.phase2-auth mschapv2 \
  802-1x.identity "w1234567@usm.edu" 802-1x.password "YOURPASSWORD" \
  802-1x.ca-cert /etc/ssl/certs/ca-certificates.crt \
  802-1x.domain-suffix-match usm.edu connection.autoconnect yes
sudo nmcli connection up eduroam
ping -c 3 google.com
```
This saves credentials system-wide so the Spark rejoins eduroam on its own after reboots.

> ⚠️ The Spark is now logged in with one person's university account. If that password changes, the Spark drops offline and someone has to fix it in person. Use Ethernet if the office has a jack.

---

## 3. Remote access with Tailscale

Tailscale gives every device a private `100.x.x.x` address reachable from anywhere, no port forwarding, works behind campus firewalls.

On the Spark:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh
```
Open the printed link and sign in.

On each teammate's laptop: install from [tailscale.com/download](https://tailscale.com/download) and sign in to the same tailnet (or have the owner invite them: admin console → Users → Invite).

> Let your professor / IT know Tailscale is running on a university network.

---

## 4. Full desktop control (mirrored on the office monitor)

Using GNOME **Desktop Sharing** means remote users control the *same* session shown on the office monitor, so the professor can see what's happening.

On the Spark:
- **Settings → System → Remote Desktop → Desktop Sharing:** enable Desktop Sharing + Remote Control, set a username/password
- **Settings → System → Users → Automatic Login:** on
- **Settings → Privacy & Security → Screen Lock:** off
- **Settings → Power:** Screen Blank → Never, Automatic Suspend → off

From a Windows laptop: open **Remote Desktop Connection** and enter the Spark's `100.x.x.x` Tailscale address. (macOS: Windows App from the App Store.)

Prefer a separate session that doesn't mirror the monitor? Use the **Remote Login** tab instead.

If Remote Desktop stops working after a reboot (GNOME keyring issue):
```bash
sudo systemctl enable gnome-remote-desktop
```

---

## 5. Terminal, VS Code, and Claude Code

### Claude Code on the Spark
```bash
curl -fsSL https://claude.ai/install.sh | bash
sudo apt install -y tmux
```

From your laptop:
```bash
ssh yourusername@100.x.x.x      # Tailscale SSH, no keys needed
tmux new -s claude              # session survives disconnects
claude
```
Reattach later with `tmux attach -t claude`.

### NVIDIA Sync (optional, no terminal needed)
[NVIDIA Sync](https://build.nvidia.com/spark/connect-to-your-spark) is NVIDIA's desktop app for using a Spark remotely: one-click VS Code, Cursor, terminal, DGX Dashboard, and custom apps like Jupyter with automatic port forwarding. It has built-in Tailscale integration.

1. Install on your laptop, add the Spark (hostname or IP + password) while on the same network
2. Settings → Tailscale → Enable → Add a Device → pick the Spark

---

## 6. Before you leave the office

- [ ] Reboot the Spark and confirm it rejoins Wi-Fi on its own
- [ ] Switch your laptop to a phone hotspot (different network) and test Remote Desktop + SSH over Tailscale
- [ ] Sleep and screen lock are off
- [ ] Quick Start card stored somewhere safe

## References
- [DGX Spark User Guide: First Boot](https://docs.nvidia.com/dgx/dgx-spark/first-boot.html)
- [DGX Spark Hardware Overview](https://docs.nvidia.com/dgx/dgx-spark/hardware.html)
- [Connect to your Spark (NVIDIA Sync playbook)](https://build.nvidia.com/spark/connect-to-your-spark)
- [NVIDIA Sync docs (Tailscale)](https://docs.nvidia.com/sync/latest/index.html)
- [USM iTech: How to connect to eduroam](https://www.usm.edu/itech/how-connect-eduroam.php)

## License
MIT. Use it, fork it, fix it.
