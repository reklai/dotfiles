#!/usr/bin/env bash
# Harder GNOME pass from 2026-09-21 yes/no answers.
# Keep: Files, Settings, Terminal (Ptyxis), Firefox, Loupe, Papers.
# Run:  bash ~/gnome-debloat.sh
# Needs sudo for dnf only.
set -euo pipefail

sudo dnf remove -y \
  'libreoffice*' \
  mediawriter \
  gnome-tour \
  gnome-maps \
  gnome-weather \
  gnome-clocks \
  gnome-contacts \
  snapshot \
  simple-scan \
  gnome-connections \
  gnome-boxes \
  qemu-kvm \
  libvirt-daemon-kvm \
  gnome-characters \
  gnome-font-viewer \
  yelp \
  gnome-user-docs \
  baobab \
  malcontent-control \
  gnome-disk-utility \
  gnome-system-monitor \
  gnome-logs \
  gnome-calculator \
  gnome-text-editor \
  gnome-classic-session

# Dock: Files + Firefox + Terminal (Calculator and Text Editor are gone).
gsettings set org.gnome.shell favorite-apps \
  "['org.mozilla.firefox.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Ptyxis.desktop']"

gsettings set org.gnome.desktop.search-providers disabled \
  "['org.gnome.Software.desktop', 'org.gnome.Calendar.desktop', 'org.gnome.Boxes.desktop', 'org.gnome.Calculator.desktop', 'org.gnome.Characters.desktop', 'org.gnome.clocks.desktop', 'org.gnome.Contacts.desktop', 'org.gnome.Weather.desktop']"

rm -f \
  "${HOME}/.local/share/applications/org.gnome.Software.desktop" \
  "${HOME}/.local/share/applications/org.gnome.Calendar.desktop" \
  "${HOME}/.local/share/applications/org.gnome.Showtime.desktop" \
  "${HOME}/.local/share/applications/org.gnome.Decibels.desktop" \
  "${HOME}/.local/share/applications/rygel.desktop" \
  "${HOME}/.local/share/applications/rygel-preferences.desktop"

update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true

cat <<'EOF'
Removed:
  LibreOffice, Media Writer, Tour, Maps, Weather, Clocks, Contacts,
  Camera, Scanner, Connections, Boxes (+ KVM/libvirt host stack),
  Characters, Fonts, Help, Disk Usage Analyzer, Parental Controls app,
  Disks, System Monitor, Logs, Calculator, Text Editor, GNOME Classic.

Kept:
  Files (Nautilus), Settings, Terminal (Ptyxis), Firefox, Loupe, Papers.

Left installed because something you kept still RPM-requires it:
  malcontent            — Settings
  geoclue2              — Settings / portals
  evolution-data-server — GNOME Shell
  localsearch           — Files
  bluez-obexd           — Bluetooth panel
EOF
