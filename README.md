# unraid-r8127-driver

Out-of-tree Realtek **r8127 / RTL8127 10GbE** driver, packaged for Unraid.

This is a community fork of [SzilagyiDaniel/Unraid-r8127][upstream] that
publishes pre-built `.txz` packages for Unraid kernels the upstream repo
hasn't released yet. Initial target: **`6.12.87-Unraid`** (Unraid 7.2.6).

The plugin downloads the right package for the running kernel from this
repo's GitHub Releases and lets Unraid auto-install it on every boot.

## Why this fork exists

The upstream plugin downloads its kernel module from a release **tagged with
the exact kernel version** (e.g. `6.12.54-Unraid`). When Unraid bumps the
kernel and the upstream repo hasn't published the matching tag yet, the
plugin silently fails on every boot and the 10G NIC drops out of the
system. Until upstream catches up, you can use this repo.

## Compatibility

| Unraid kernel | Status | Release tag |
|---|---|---|
| `6.12.87-Unraid` (Unraid 7.2.6) | ✅ Available | [6.12.87-Unraid](https://github.com/jandrop/unraid-r8127-driver/releases/tag/6.12.87-Unraid) |
| Older or newer kernels | ⚠️ Build it yourself with `scripts/build.sh` and open a PR/issue with the .txz |

If you need a kernel that's not listed here, the easiest path is to run
`scripts/build.sh` on your Unraid box (Docker required) — it pulls
the matching kernel source and the upstream Realtek driver, then spits out a
`.txz` you can drop into `/boot/extra/`.

## Hardware tested

- Realtek **RTL8127** PCIe 10GbE controller (PCI ID `10ec:8127`)
- Plugin built and validated on an i5-10600K box running Unraid 7.2.6

## Install (recommended)

In Unraid GUI → **Plugins → Install Plugin**, paste:

```
https://raw.githubusercontent.com/jandrop/unraid-r8127-driver/main/unraid-r8127-driver.plg
```

Reboot. The plugin will:

1. Blacklist the in-tree `r8169` driver (which doesn't support RTL8127).
2. Download `r8127-<date>-<kernel>-1.txz` matching your running kernel from
   this repo's release matching `uname -r`.
3. Verify its md5 and copy it into `/boot/extra/` so Unraid auto-installs it
   on every subsequent boot.
4. Run `modprobe r8127`.
5. If the network bond was already set up before the driver loaded,
   restart networking once so the bond picks up the new interface
   (see [Boot-order fix](#boot-order-fix-eth1-not-in-bond) below).

## Configure the network

After the driver loads, the new 10G interface shows up as `eth1` (or `eth2`
if you already had two NICs). Go to **Settings → Network Settings** and
either:

- **Bond it** with your existing NIC (active-backup) so 10G is primary
  and the slower NIC takes over only on link failure, or
- Use it as a **standalone interface** with its own IP.

If you want the UDM Pro / your DHCP server to give the bond a fixed IP,
**reserve it for the MAC of the 10G card**, not the 1G one — that's the
MAC the bond will use after the driver is loaded.

## Boot-order fix (eth1 not in bond)

Unraid's `rc.inet1` brings the network up **before** `rc.local` installs
packages from `/boot/extra/`. Result: the first time the bond is created,
the 10G card doesn't exist yet, so `eth1` is silently dropped and the bond
falls back to the 1G NIC's MAC.

The plugin detects this on boot and triggers a single `rc.inet1 restart`
in the background, after which the bond comes back up with the 10G MAC and
the DHCP lease/reservation switches to the right one.

You'll see a brief network blip during early boot — that's normal and only
happens once per reboot.

## Uninstall

Use **Plugins → Installed Plugins → Remove**, or:

```bash
plugin remove r8127-driver
rm /boot/extra/r8127-*.txz
sed -i '/blacklist r8169/d' /boot/config/modprobe.d/r8169.conf
```

…then reboot.

## Build for a new kernel

You'll need a working Unraid box with Docker enabled. On the server:

```bash
curl -sL https://raw.githubusercontent.com/jandrop/unraid-r8127-driver/main/scripts/build.sh | bash
```

The script:

1. Downloads kernel source matching `uname -r` from
   [`ich777/unraid_kernel`](https://github.com/ich777/unraid_kernel/releases).
2. Downloads driver source from
   [`SzilagyiDaniel/Unraid-r8127`](https://github.com/SzilagyiDaniel/Unraid-r8127).
3. Compiles `r8127.ko` inside a `gcc:14` Docker container.
4. Strips debug symbols.
5. Packages everything as `r8127-<date>-<kernel>-1.txz` plus an `.md5`.

After it finishes you can either upload both files as assets on a GitHub
Release tagged with the exact kernel string (e.g. `6.12.95-Unraid`), or
just drop the `.txz` into `/boot/extra/` and `installpkg` it locally.

## Credits

- Realtek for the [r8127 driver source](https://www.realtek.com/Download/List?cate_id=584).
- [`SzilagyiDaniel/Unraid-r8127`][upstream] — original Unraid plugin design
  and source mirror; this repo is a thin community fork.
- [`ich777/unraid_kernel`](https://github.com/ich777/unraid_kernel) for
  publishing matching Unraid kernel source tarballs.

## License

GPL-2.0 — see [LICENSE](LICENSE).

## Support

Issues, requests for new kernel builds, or hardware reports:
[**Open an issue**](https://github.com/jandrop/unraid-r8127-driver/issues).

If this saved your weekend, you can ☕
[buy me a coffee on Ko-fi](https://ko-fi.com/jandrop) or
[sponsor on GitHub](https://github.com/sponsors/jandrop).

[upstream]: https://github.com/SzilagyiDaniel/Unraid-r8127
