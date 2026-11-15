#!/bin/sh
# Enable hang/lockup diagnostics for the silent-reset problem on x1e80100.
# Run as root. Edits /usr/src/linux/.config only; does not build.
set -eu

KSRC=${KSRC:-/usr/src/linux}
cd "$KSRC"
cp .config ".config.pre-debug.$(date +%Y%m%d-%H%M%S)"

c() { scripts/config --file .config "$@"; }

# --- Lockup / hang detectors -------------------------------------------
c -e LOCKUP_DETECTOR
c -e SOFTLOCKUP_DETECTOR
c --set-val BOOTPARAM_SOFTLOCKUP_PANIC 1      # int now: panic after 1x20s -> kmsg dumped to pstore
c -e HARDLOCKUP_DETECTOR
c -e HARDLOCKUP_DETECTOR_PREFER_BUDDY    # buddy works without pseudo-NMI
c -e BOOTPARAM_HARDLOCKUP_PANIC
c -e DETECT_HUNG_TASK
c --set-val DEFAULT_HUNG_TASK_TIMEOUT 60
c --set-val BOOTPARAM_HUNG_TASK_PANIC 0      # int now; 0 = warn only
c -e WQ_WATCHDOG

# Lets the buddy detector backtrace a CPU stuck with IRQs masked.
# Inert unless irqchip.gicv3_pseudo_nmi=1 is on the cmdline.
c -e ARM64_PSEUDO_NMI

# Reboot 10s after a panic instead of sitting there
c --set-val PANIC_TIMEOUT 10

# --- pstore / ramoops ----------------------------------------------------
c -e PSTORE
c -e PSTORE_RAM                          # was =m, needs to be up early
c -e PSTORE_CONSOLE                      # continuous console capture, not just panics
c -e PSTORE_COMPRESS

# --- GPU crash state -----------------------------------------------------
c -e DRM_MSM_GPU_STATE
c -e DEVCOREDUMP

# --- Noise reduction -----------------------------------------------------
c -d USB_STORAGE_DEBUG                   # was flooding kern.log with every TUR

make olddefconfig >/dev/null

echo "Resulting values:"
grep -E "^(# )?CONFIG_(LOCKUP_DETECTOR|SOFTLOCKUP_DETECTOR|BOOTPARAM_SOFTLOCKUP_PANIC|HARDLOCKUP_DETECTOR|HARDLOCKUP_DETECTOR_PREFER_BUDDY|HARDLOCKUP_DETECTOR_BUDDY|BOOTPARAM_HARDLOCKUP_PANIC|DETECT_HUNG_TASK|DEFAULT_HUNG_TASK_TIMEOUT|WQ_WATCHDOG|ARM64_PSEUDO_NMI|PANIC_TIMEOUT|PSTORE|PSTORE_RAM|PSTORE_CONSOLE|DRM_MSM_GPU_STATE|DEVCOREDUMP|USB_STORAGE_DEBUG)[ =]" .config

cat <<'EOF'

Now add to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub:

  sbsa_gwdt.timeout=60 reserve_mem=4M:4096:oops ramoops.mem_name=oops ramoops.console_size=1048576 ramoops.record_size=131072 ramoops.ecc=1 sysctl.kernel.panic_on_rcu_stall=1

Optional, second pass (needs the pseudo-NMI config above; drop it if boot misbehaves):

  irqchip.gicv3_pseudo_nmi=1

Then grub-mkconfig -o /boot/grub/grub.cfg, build, install, reboot.
After the next crash: ls /sys/fs/pstore/
EOF
