#!/usr/bin/env python3
import sys, os, logging, argparse, re, shlex, subprocess, tempfile

logging.basicConfig(level=logging.NOTSET,
		format="[%(asctime)s][%(levelname)s][%(name)s][%(funcName)s][#%(lineno)d]%(message)s")

logger = logging.getLogger("sd")

def guessIpy():
	try:
		return get_ipython().__class__.__name__
	except:
		pass

def shRun(cmd, **kwargs):
	resp = subprocess.run(cmd, shell=True, text=True, capture_output=True
			# , stderr=subprocess.STDOUT
			, **kwargs)
	return resp.returncode, resp.stdout.strip()

def main(argv = sys.argv):
	argc = len(argv)
	# logger.debug("argc: {}, argv: {}".format(argc, argv))

	argparser = argparse.ArgumentParser(prog=os.path.basename(argv[0]),
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	argparser.add_argument("--sz1", default=250, type=int, help="Size of 1st partition in MB")
	argparser.add_argument("--offset1", default=2, type=int, help="Offset of 1st partition in MB")
	argparser.add_argument("--bpiboot", default=None, help="Bootloader for BPI, u-boot-sunxi-with-spl.bin")
	argparser.add_argument("-q", "--quiet",  action="store_true", help="Less user interaction")
	argparser.add_argument("-n", "--dryrun", action="store_true", help="No harm action only")
	argparser.add_argument("dev", default=None, help="SDCard Device")

	argc = len(argv)
	if argc <= 1:
		argparser.print_help()
		sys.exit(1)

	args = argparser.parse_args(argv[1:])
	# logger.debug("argc: {}, args: {}".format(argc, args))

	devPartSep = ""
	if re.match("/dev/mmcblk[0-9].*", args.dev):
		logger.info("Guessed mmcblk")
		devPartSep = "p"

	devBus = "Any"
	while devBus == "Any":
		eno, resp = shRun(f"udevadm info -q path {args.dev}")
		logger.debug(f"udevadm return code: {eno}, stdout:\n{resp}")
		if eno != 0:
			logger.error("Failed get udevadm info")
			sys.exit(1)
		if re.match("/devices/.*/usb[0-9]*/.*", resp):
			devBus = "USB"
			logger.info(f"Guessed {devBus} (udev: {resp})")
			break
		logger.error(f"System might corrupt when use {args.dev} (udev: {resp})")
		sys.exit(1)

	print(f"Request sudo to list partition of {args.dev}")
	sudo = "sudo"
	if not args.quiet:
		sudo += " -k"
	eno, resp = shRun(f"{sudo} sfdisk -l {args.dev}")
	logger.debug(f"{sudo} sfdisk return code: {eno}, stdout:\n{resp}")
	if eno != 0:
		logger.error("Failed list partition")
		sys.exit(1)

	if not args.quiet:
		input(f"Ctrl-C to break or press Enter to continue")

	# 0xc W95 FAT32 (LBA)
	# 0x6 fat16
	fs1FatId=0xc

	cmd = f"sudo sfdisk {args.dev}"
	cmdIn = (f"{args.offset1}M,{args.sz1}M,{fs1FatId:x}"
			f"\n{args.sz1 + 1}M,,L,-")
	if args.dryrun:
		logger.info(f"dryrun: {cmd}\nstdin:\n{cmdIn}")
	else:
		eno, resp = shRun(cmd, input=cmdIn)
		logger.debug(f"sudo sfdisk return code: {eno}, stdout:\n{resp}")
		if eno != 0:
			logger.error("Failed partition")
			sys.exit(1)

	# for slow machine
	shRun("sync; sleep 1")

	cmd = f"sudo mkfs.fat"
	if fs1FatId == 0xc:
		cmd += " -F 32"
	elif fs1FatId == 0x6:
		cmd += " -F 16"
	else:
		logger.error("Unknown fatfs size")
		sys.exit(1)
	cmd += f" -n BOOT {args.dev}{devPartSep}1"
	if args.dryrun:
		logger.info(f"dryrun: {cmd}")
	else:
		eno, resp = shRun(cmd)
		logger.debug(f"sudo mkfs.fat return code: {eno}, stdout:\n{resp}")
		if eno != 0:
			logger.error("Failed sudo mkfs.fat")
			sys.exit(1)

	cmd = f"sudo mkfs.ext4 -L rootfs {args.dev}{devPartSep}2"
	if args.dryrun:
		logger.info(f"dryrun: {cmd}")
	else:
		eno, resp = shRun(cmd)
		logger.debug(f"sudo mkfs.ext4 return code: {eno}, stdout:\n{resp}")
		if eno != 0:
			logger.error("Failed mkfs.ext4")
			sys.exit(1)

	if args.bpiboot:
		cmd = f"sudo dd if={args.bpiboot} of={args.dev} bs=1024 seek=8"
		eno, resp = shRun(cmd)
		logger.debug(f"sudo dd {args.bpiboot} return code: {eno}, stdout:\n{resp}")
		if eno != 0:
			logger.error("Failed sudo dd")
			sys.exit(1)

	with tempfile.TemporaryDirectory() as tmpdir:
		logger.debug(f"tmpdir: {tmpdir}")
		cmd = f"sudo mount {args.dev}{devPartSep}2 {tmpdir}"
		if args.dryrun:
			logger.info(f"dryrun: {cmd}")
		else:
			eno, resp = shRun(cmd)
			logger.debug(f"sudo mount {args.dev}{devPartSep}2 return code: {eno}, stdout:\n{resp}")
			if eno != 0:
				logger.error(f"Failed mount {args.dev}{devPartSep}2")
				sys.exit(1)

		cmd = f"sudo chmod 0777 {tmpdir}"
		if args.dryrun:
			logger.info(f"dryrun: {cmd}")
		else:
			eno, resp = shRun(cmd)
			logger.debug(f"sudo chmod 0777 return code: {eno}, stdout:\n{resp}")
			if eno != 0:
				logger.error(f"Failed chmod 0777")
				sys.exit(1)

		cmd = f"sudo umount {tmpdir}"
		if args.dryrun:
			logger.info(f"dryrun: {cmd}")
		else:
			eno, resp = shRun(cmd)
			logger.debug(f"sudo umount return code: {eno}, stdout:\n{resp}")
			if eno != 0:
				logger.error(f"Failed umount")
				sys.exit(1)

	shRun("sync; sleep 1")

# jupyter?
if __name__ == "__main__":
	if ipy := guessIpy():
		# logger.debug("guess ipython {}".format(ipy))
		argv = shlex.split("sd.py -n /dev/sde".split())
		main(argv)
	else:
		main(sys.argv)
