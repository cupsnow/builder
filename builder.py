#!/usr/bin/env python3
# compatable python3.8 later

import inspect, logging, os, subprocess

logger = logging.getLogger("builder")

def verHex4(verStr):
	verSep = verStr.split(".")
	verNum = 0
	for i in range(min(4, len(verSep))):
		verNum = verNum + (int(verSep[i]) << (8 * (3 - i)))
	return verNum

def strInt(ns, base = 0):
	try:
		return int("{}".format(ns), base)
	except:
		pass
	return int("0x" + ns, 0)

def guess_ipy():
	try:
		return get_ipython().__class__.__name__
	except:
		pass

def run_cmd(cmd, **kwargs):
	'''
	example:

	resp = run_cmd("env | grep -i path", PATH="bin1:bin2", LD_LIBRARY_PATH="lib1:lib1")
	logger.debug(f"return code: {resp.returncode}, stdout: {resp.stdout}")
	'''
	ext = {}
	env = kwargs.pop("env", dict(os.environ.copy()))
	for k in ["LD_LIBRARY_PATH", "PATH"]:
		klst = [*kwargs.pop(k, "").split(os.pathsep),
				*env.pop(k, "").split(os.pathsep)]
		klst = [x for x in dict.fromkeys(klst) if x]
		if klst:
			env.update({k: os.pathsep.join(klst)})
	#  If you wish to capture and combine both streams into one, use stdout=PIPE and stderr=STDOUT instead of capture_output
	resp = subprocess.run(cmd, shell=True, text=True, env=env
			# , capture_output=True
			, stdout=subprocess.PIPE, stderr=subprocess.STDOUT
			, **kwargs)
	return resp

def gNum(num):
	"""Convert to integer when all zero after decimal point

	Args:
		num (int or float): Testing value

	Returns:
		int or float: _description_
	"""
	if (type(num) is type(1.1)) and (num == int(num)):
		return int(num)
	return num

iesMagSuf = ( (1 << 60, "E"), (1 << 50, "P"), (1 << 40, "T"),
		(1 << 30, "G"), (1 << 20, "M"), (1 << 10, "k") )

def iecStr(num):
	for ms in iesMagSuf:
		if (num >= ms[0]):
			return "{:g}{}".format(gNum(num / ms[0]), ms[1])
	return "{:g}".format(gNum(num))

def iecIntStr(num):
	for ms in iesMagSuf:
		mag = num / ms[0]
		if num >= ms[0] and float(mag) == int(mag):
			return "{:g}{}".format(int(mag), ms[1])
	return "{:g}".format(gNum(num))

def hexStr(str, sep = ""):
	strOut = sep.join("{:02x}".format(x) for x in str.encode())
	return strOut

def partListRefine(partList, partTotal):
	"""Refine offset for partList.

	The format for partition description object is

	{"name": <str>, "offset": <integer>, "size": <integer>}

	Refine missing member in partition description object.
	  - The first partition offset = 0.
	  - Offset following the previous partition.
	  - The Last partition size occupy all remain flash.

	Args:
		partList (list): List of partition description
		partTotal (int): Size of flash

	Raises:
		Exception: any error

	Returns:
		int: Used size
	"""
	part = partList[0]
	if "offset" not in part:
		part["offset"] = 0
	for idx in range(1, len(partList)):
		part = partList[idx]
		prevPart = partList[idx - 1]
		prevPartNext = prevPart["offset"] + prevPart["size"]
		if prevPartNext > partTotal:
			raise Exception("part \"{}\" over flash size".format(part["name"]))
		if "offset" not in part:
			part["offset"] = prevPartNext
		elif part["offset"] < prevPartNext:
			raise Exception("part \"{}\" overlap".format(part["name"]))
	part = partList[-1]
	if "size" not in part:
		flashSpare = partTotal - part["offset"]
		if flashSpare <= 0:
			raise Exception("part \"{}\" over flash size".format(part["name"]))
		part["size"] = flashSpare
	partNext = part["offset"] + part["size"]
	if partNext > partTotal:
		raise Exception("part \"{}\" over flash size".format(part["name"]))
	# logger.debug("flash used size {}".format(iecStr(partNext)))
	return partNext

def partListDump(partList):
	strList = []
	for part in partList:
		try:
			strList.append("{:11s} 0x{:08x} 0x{:08x} {}".format(part["name"],
					part["offset"], part["size"], iecIntStr(part["size"])))
		except:
			raise Exception("Invalid partition expression: {}".format(part))
	return "\n".join(strList)

def mtdPartsDump(partList):
	strList = []
	for part in partList:
		str2 = "{}({})".format(iecIntStr(part["size"]), part["name"])
		if "ro" in part:
			str2 = str2 + "ro"
		strList.append(str2)
	return ",".join(strList)

def hdParse(str, base = 16):
	"""Parse hexdump liked data into array

	Example:
		# ethtool -e eth1
		Offset          Values
		------          ------
		0x0000:         15 5a ec 75 20 12 29 27 00 0e c6 00 37 ee 09 04
		0x0010:         60 22 71 12 19 0e 3d 04 3d 04 3d 04 3d 04 80 05
		0x0020:         00 06 10 e0 42 24 40 12 49 27 ff ff 00 00 ff ff
		0x0030:         c0 09 0e 03 30 00 30 00 33 00 37 00 45 00 45 00
		0x0040:         12 01 00 02 ff ff 00 40 95 0b 2b 77 02 00 01 02
		0x0050:         03 01 09 02 27 00 01 01 04 a0 64 09 04 00 00 03
		0x0060:         ff ff 00 07 07 05 81 03 08 00 0b 07 05 82 02 00
		0x0070:         02 00 07 05 03 02 00 02 00 ff 04 03 30 00 ff ff

	Args:
		str (_type_): _description_
		base (int, optional): _description_. Defaults to 16.
	"""
	arr = []
	for line in str.splitlines():
		# logger.debug(line)
		line2 = line.strip()
		if (len(line2) <= 0 or line2.startswith("#") or line2.startswith(";") or
				line2.startswith("$")):
			continue
		lineTok = line2.split()
		lineArr = []
		for i in range(len(lineTok)):
			try:
				lineArr.append(strInt(lineTok[i], base))
			except:
				if i != 0:
					lineArr.clear()
					break
		if len(lineArr) < 1:
			# logger.debug("abandon line: {}".format(line2))
			continue
		# line3 = ",".join(["{:x}".format(x) for x in lineArr])
		# logger.debug("parsed line: {} to count {},\n{}".format(line2, len(lineArr), line3))
		arr.extend(lineArr)
	return arr

def shEnv(*extpath):
	env = os.environ.copy()
	env["PATH"] = os.pathsep.join([*extpath, env["PATH"]])
	return env

def shRun(cmd, **kwargs):
	if ((kwargs.get("env") == None)
			and (extpath := kwargs.pop("extpath", None))):
		kwargs.update({"env": shEnv(*extpath)})
	resp = subprocess.run(cmd, shell=True, capture_output=True, text=True,
			**kwargs)
	return resp.returncode, resp.stdout.strip()
