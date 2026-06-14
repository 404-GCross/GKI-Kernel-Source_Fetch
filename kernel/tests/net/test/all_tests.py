#!/usr/bin/python3
#
# Copyright 2018 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import ctypes
import importlib
import os
import sys
import unittest

import gki
import namespace
import net_test

# man 2 personality
personality = ctypes.CDLL(None).personality
personality.restype = ctypes.c_int
personality.argtypes = [ctypes.c_ulong]

# From Linux kernel's include/uapi/linux/personality.h
PER_QUERY = 0xFFFFFFFF
PER_LINUX = 0
PER_LINUX32 = 8

all_test_modules = [
    'anycast_test',
    'bpf_test',
    'csocket_test',
    'cstruct_test',
    'kernel_feature_test',
    'leak_test',
    'multinetwork_test',
    'neighbour_test',
    'netlink_test',
    'nf_test',
    'parameterization_test',
    'ping6_test',
    'policy_crash_test',
    'resilient_rs_test',
    'sock_diag_test',
    'srcaddr_selection_test',
    'sysctls_test',
    'tcp_fastopen_test',
    'tcp_nuke_addr_test',
    'tcp_repair_test',
    'xfrm_algorithm_test',
    'xfrm_test',
    'xfrm_tunnel_test',
]


def RunTests(modules_to_test):
  uname = os.uname()
  linux = uname.sysname
  kver = uname.release
  arch = uname.machine
  p = personality(PER_LINUX)
  true_arch = os.uname().machine
  personality(p)
  print('Running on %s %s %s %s/%s-%sbit%s%s'
        % (linux, kver, net_test.LINUX_VERSION, true_arch, arch,
           '64' if sys.maxsize > 0x7FFFFFFF else '32',
           ' GKI' if gki.IS_GKI else '', ' GSI' if net_test.IS_GSI else ''),
        file=sys.stderr)
  namespace.EnterNewNetworkNamespace()

  # First, run InjectTests on all modules, to ensure that any parameterized
  # tests in those modules are injected.
  for name in modules_to_test:
    importlib.import_module(name)
    if hasattr(sys.modules[name], 'InjectTests'):
      sys.modules[name].InjectTests()

  test_suite = unittest.defaultTestLoader.loadTestsFromNames(modules_to_test)

  assert test_suite.countTestCases() > 0, (
      'Inconceivable: no tests found! Command line: %s' % ' '.join(sys.argv))

  runner = unittest.TextTestRunner(verbosity=2)
  result = runner.run(test_suite)
  sys.exit(not result.wasSuccessful())


if __name__ == '__main__':
  # If one or more tests were passed in on the command line, only run those.
  if len(sys.argv) > 1:
    RunTests(sys.argv[1:])
  else:
    RunTests(all_test_modules)
