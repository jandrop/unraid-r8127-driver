#!/bin/bash
# Build the r8127 OOT driver as a Slackware .txz package against the running
# Unraid kernel. Designed to run on the Unraid server itself (Docker required).
#
# Output: /tmp/build/r8127-<DATE>-<KERNEL>-1.txz  (and a .md5 alongside).
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/jandrop/unraid-r8127-driver/main/scripts/build.sh | bash
#   # or
#   bash scripts/build.sh
#
# After it finishes, upload the .txz + .md5 as assets on the GitHub Release
# tagged with the kernel version (e.g. tag "6.12.87-Unraid"), or copy them
# straight into /boot/extra/ on the same machine and reboot.

set -euo pipefail

KVER="$(uname -r)"
DATE="$(date +%Y%m%d)"
BUILD="/tmp/build"
KERNEL_DIR="${BUILD}/kernel"
DRIVER_DIR="${BUILD}/r8127"
PKG_DIR="${BUILD}/pkg"
KSRC_URL="https://github.com/ich777/unraid_kernel/releases/download/${KVER}/linux-${KVER}.tar.xz"
DRIVER_BASE="https://raw.githubusercontent.com/SzilagyiDaniel/Unraid-r8127/master/r8127"

echo "Building r8127 OOT driver for kernel ${KVER}"
echo

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found. Build needs the Docker daemon (Unraid has it built in)."
  exit 1
fi

mkdir -p "${BUILD}" "${KERNEL_DIR}" "${DRIVER_DIR}/src"

# 1. Kernel source matching the running kernel.
if [ ! -f "${KERNEL_DIR}/Makefile" ]; then
  echo "==> Downloading kernel source ${KVER}"
  TARBALL="${BUILD}/linux-${KVER}.tar.xz"
  if [ ! -f "${TARBALL}" ]; then
    wget -q --show-progress -O "${TARBALL}" "${KSRC_URL}"
  fi
  tar xf "${TARBALL}" -C "${KERNEL_DIR}"
fi

# 2. Driver source from upstream (SzilagyiDaniel mirrors Realtek's r8127).
echo "==> Downloading driver source"
for f in Makefile README autorun.sh; do
  wget -q -O "${DRIVER_DIR}/${f}" "${DRIVER_BASE}/${f}"
done
for f in Makefile Makefile_linux24x r8127.h r8127_dash.h r8127_fiber.c \
         r8127_fiber.h r8127_firmware.c r8127_firmware.h r8127_n.c \
         r8127_ptp.c r8127_ptp.h r8127_realwow.h r8127_rss.c r8127_rss.h \
         rtl_eeprom.c rtl_eeprom.h rtltool.c rtltool.h; do
  wget -q -O "${DRIVER_DIR}/src/${f}" "${DRIVER_BASE}/src/${f}"
done

# 3. Compile inside a gcc:14 container (matches Slackware-current-ish ABI well
#    enough for kernel module ABI; vermagic only checks the kernel string).
echo "==> Compiling r8127.ko inside gcc:14 container"
docker pull -q gcc:14 >/dev/null
docker run --rm -v "${BUILD}:/build" -w /build/r8127/src gcc:14 \
  bash -c "make -C /build/kernel M=/build/r8127/src modules"

# 4. Strip debug info to keep the package small.
docker run --rm -v "${BUILD}:/build" gcc:14 \
  strip --strip-debug /build/r8127/src/r8127.ko

# 5. Build the Slackware .txz layout.
echo "==> Packaging .txz"
rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}/lib/modules/${KVER}/extra" "${PKG_DIR}/install"
cp "${DRIVER_DIR}/src/r8127.ko" "${PKG_DIR}/lib/modules/${KVER}/extra/"
printf '#!/bin/sh\n/sbin/depmod -a %s 2>/dev/null\n' "${KVER}" > "${PKG_DIR}/install/doinst.sh"
chmod +x "${PKG_DIR}/install/doinst.sh"
{
  echo '      |-----handy-ruler------------------------------------------------------|'
  echo 'r8127: r8127 (Realtek RTL8127 10GbE OOT driver)'
  echo 'r8127:'
  echo 'r8127: Out-of-tree driver for Realtek RTL8127 10 Gigabit Ethernet controllers.'
  echo 'r8127: Built locally for the running Unraid kernel.'
  echo 'r8127:'
  echo 'r8127: Source: https://github.com/SzilagyiDaniel/Unraid-r8127'
  echo 'r8127: Plugin: https://github.com/jandrop/unraid-r8127-driver'
  for _ in 1 2 3 4; do echo 'r8127:'; done
} > "${PKG_DIR}/install/slack-desc"

OUT="${BUILD}/r8127-${DATE}-${KVER}-1.txz"
( cd "${PKG_DIR}" && echo n | /sbin/makepkg -l y -c n "${OUT}" ) >/dev/null
md5sum "${OUT}" | awk '{print $1"  "$2}' | sed "s|.*/||" > "${OUT}.md5"

echo
echo "==> Build complete"
ls -lh "${OUT}" "${OUT}.md5"
echo
echo "Next steps:"
echo "  - Upload as assets on GitHub Release with tag '${KVER}', or"
echo "  - Copy to /boot/extra/ and reboot:"
echo "      cp ${OUT} /boot/extra/"
echo "      /sbin/installpkg ${OUT}"
echo "      modprobe r8127"
