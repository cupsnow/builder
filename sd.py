#!/usr/bin/env python3
#%%
# define functions

import sys, os, json, logging, argparse, re
import shlex, shutil, io, subprocess, threading, time

logging.basicConfig(level=logging.NOTSET, format="[%(asctime)s][%(levelname)s][%(name)s][%(funcName)s][#%(lineno)d]%(message)s")

logger = logging.getLogger("sd")

def guessIpy():
	try:
		return get_ipython().__class__.__name__
	except:
		pass

#%%
# Start main

def main(argv = sys.argv):
	argc = len(argv)
	# logger.debug("argc: {}, argv: {}".format(argc, argv))

	argparser = argparse.ArgumentParser(prog=os.path.basename(argv[0]),
			formatter_class=argparse.ArgumentDefaultsHelpFormatter)
	argparser.add_argument("--sz1", default=250, help="Size of 1st partition in MB")
	argparser.add_argument("--offset1", default=2, help="Offset of 1st partition in MB")
	argparser.add_argument("-q", "--quiet",  action="store_true", help="Less user interaction")
	argparser.add_argument("-n", "--dryrun", action="store_true", help="No harm action only")
	argparser.add_argument("dev", help="SDCard Device")

	args = argparser.parse_args(argv[1:])
	logger.debug("argc: {}, args: {}".format(argc, args))

	devPartSep = ""
	if re.match("/dev/mmcblk[0-9].*", args.dev):
		logger.debug("guess mmcblk")
		devPartSep = "p"

	# sanity check bus of dev (assume usb card reader)
	if not (udevadm := shutil.which("udevadm")):
		raise RuntimeError("Miss udevadm")
	cli = shlex.split(udevadm + " info -q path " + args.dev)
	logger.debug("udevadm cli: {}".format(cli))
	with subprocess.Popen(cli, stdout=subprocess.PIPE, text=True,
			universal_newlines=True) as proc:
		ostr, estr = proc.communicate(timeout=3)
	logger.debug("udevadm output: {}".format(ostr))

	udevPath = ostr
	while devBus := "Any":
		if re.match("/devices/.*/usb[0-9]*/.*", udevPath):
			devBus = "USB"
			logger.debug("guess {}: {}".format(devBus, udevPath))
			break
		raise RuntimeError("System might corrupt when use {} (udev: {})".format(
				args.dev, udevPath))

	print("Request sudo to list partition of {}".format(args.dev))
	cli = "sudo -k sfdisk -l {}".format(args.dev)
	logger.debug("sfdisk cli: {}".format(cli))
	with subprocess.Popen(cli, shell=True, stdout=subprocess.PIPE, text=True,
			universal_newlines=True) as proc:
		ostr, estr = proc.communicate()
	logger.debug("sfdisk output:\n{}".format(ostr))

	msg="Ctrl-C to break or input something to continue"
	if (not args.dryrun) and (not args.quiet):
		s = input("{}: ".format(msg))
		# if not s:
		# 	logger.debug("read nothing")
		# 	sys.exit(1)
		# logger.debug("read: {}".format(s))

	print("Request sudo to partition {}".format(args.dev))
	# c W95 FAT32 (LBA)
	# fs1FatId=0x6
	fs1FatId=0xc
	cli = "sudo sfdisk {}".format(args.dev)
	procInput = ("{}M,{}M,0x{:x},"
		"\n{}M,,,-".format(args.offset1, args.sz1, fs1FatId,
		args.sz1 + 1))
	logger.debug("sfdisk cli: {}".format(cli))
	if args.dryrun:
		print("Bypass for dryrun")
	else:
		with subprocess.Popen(cli, shell=True, stdout=subprocess.PIPE,
				stdin=subprocess.PIPE, text=True, universal_newlines=True) as proc:
			proc.stdin.write(procInput)
			proc.stdin.close()
			rc = proc.wait(10)
			procOutput = proc.stdout.read()
		logger.debug("sfdisk ret: {}, output:\n{}".format(rc, procOutput))

# jupyter?
if ipy := guessIpy():
	logger.debug("guess ipython {}".format(ipy))
	argv = "sd.py -n /dev/sde".split()
	main(argv)

elif __name__ == "__main__":
	main(sys.argv)
