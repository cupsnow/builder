#!/usr/bin/env python3

import inspect
import logging
import os
import subprocess

logger = logging.getLogger("builder")


def guess_ipy():
    """ipython class name.

    Returns:
        str: ipython class name
    """
    try:
        return get_ipython().__class__.__name__
    except:
        pass


def run_cmd(cmd, **kwargs):
    """Run command in shell

    Args:
        cmd (str): Command line string.

    Returns:
        subprocess.CompletedProcess: Completed process

    Example:

        resp = run_cmd("env | grep -i path", PATH="bin1:bin2", LD_LIBRARY_PATH="lib1:lib1")
        logger.debug(f"return code: {resp.returncode}, stdout: {resp.stdout}")
    """
    ext = {}
    env = kwargs.pop("env", dict(os.environ.copy()))
    for k in ["LD_LIBRARY_PATH", "PATH"]:
        klst = [*kwargs.pop(k, "").split(os.pathsep),
                *env.pop(k, "").split(os.pathsep)]
        klst = [x for x in dict.fromkeys(klst) if x]
        if klst:
            env.update({k: os.pathsep.join(klst)})
    #  If you wish to capture and combine both streams into one, use stdout=PIPE and stderr=STDOUT instead of capture_output
    resp = subprocess.run(cmd, shell=True, text=True, env=env                          # , capture_output=True
                          , stdout=subprocess.PIPE, stderr=subprocess.STDOUT, **kwargs)
    return resp
