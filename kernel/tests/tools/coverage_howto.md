HOW TO COLLECT KERNEL CODE COVERAGE FROM A TEST RUN
===================================================


## 1. Build and use a kernel with GCOV profile enabled
### Build and install with scripts
Build and install a GCOV kernel on a Cuttlefish or physical device with one of
the following commands:
```
$ kernel/tests/tools/launch_cvd.sh --gcov
```
```
$ kernel/tests/tools/flash_device.sh --gcov
```
To view available options, run the scripts with `--help`.

### Build on your own
Build a kernel with
[`--gcov`](https://android.googlesource.com/kernel/build/+/refs/heads/main/kleaf/docs/gcov.md)
option. This will also trigger the build to save the required *.gcno files
needed to viewing the collected count data.

For example, build a Cuttlefish kernel with GCOV:
```
$ tools/bazel run --gcov //common-modules/virtual-device:virtual_device_x86_64_dist
```

## 2. Run tests with kernel coverage collection enabled
### `run_test_only.sh`
Collect test coverage data with `run_test_only.sh --gcov` and the required
options. For example,

```
$ kernel/tests/tools/run_test_only.sh --gcov \
    --serial 0.0.0.0:6520 --test='selftests kselftest_net_socket'
```

To view available options, run the script with `--help`.

### `tradefed.sh`
Adding the appropriate coverage flags to the tradefed call will trigger it to
take care of mounting debugfs, reseting the gcov counts prior to test run, and
collecting gcov data files from debugfs after test completion. These coverage
arguments are:
```
--coverage --coverage-toolchain GCOV_KERNEL --auto-collect GCOV_KERNEL_COVERAGE
```

The following is a full example call running just the `kselftest_net_socket`
test in the selftests test suite that exists under the `out/tests/testcases`
directory. The artifact output has been redirected to `tf-logs` for easier
reference needed in the next step.
```
$ prebuilts/tradefed/filegroups/tradefed/tradefed.sh run commandAndExit \
    template/local_min --template:map test=suite/test_mapping_suite     \
    --include-filter 'selftests kselftest_net_socket'                   \
    --tests-dir=out/tests/testcases                                     \
    --primary-abi-only --log-file-path tf-logs                          \
    --coverage --coverage-toolchain GCOV_KERNEL                         \
    --auto-collect GCOV_KERNEL_COVERAGE
```

## 3. Create an lcov tracefile out of the gcov tar artifact from test run
The previously mentioned `run_test_only.sh` or `tradefed.sh` run will produce
a tar file artifact in the log folder with a name like
`<test>_kernel_coverage_*.tar.gz`. This tar file is an archive of all the gcov
data files collected into debugfs from the profiled device. In order to make
it easier to work with this data, it needs to be converted to a single lcov
tracefile.

The script `create-tracefile.py` facilitates this generation by handling the
required unpacking, file path corrections and ultimate `lcov` call.
`run_test_only.sh` calls `create-tracefile.py` automatically if it can locate
the kernel source. Otherwise, it shows the arguments for you to run
`create-tracefile.py` in the kernel source tree.

If you use `tradefed.sh`, you need to issue the `create-tracefile.py` command.
The following is an example where we generate a tracefile named `cov.info`
only including results from `net/socket.c`. (If no source files are specified
as included, then all source file data is used.)
```
$ kernel/tests/tools/create-tracefile.py -t tf-logs --include net/socket.c
```

## 4. Visualizing results
With the created tracefile, there are a number of different ways to view
coverage data from it. Check out `man lcov` for more options.
### Summary
```
$ lcov --summary --rc lcov_branch_coverage=1 cov.info
Reading tracefile cov.info_fix
Summary coverage rate:
  lines......: 6.0% (81646 of 1370811 lines)
  functions..: 9.6% (10285 of 107304 functions)
  branches...: 3.7% (28639 of 765538 branches)
```
### List
```
$ lcov --list --rc lcov_branch_coverage=1 cov.info
Reading tracefile cov.info_fix
                                               |Lines      |Functions|Branches
Filename                                       |Rate    Num|Rate  Num|Rate   Num
================================================================================
[/usr/local/google/home/joefradley/dev/common-android-mainline-2/common/]
arch/x86/crypto/aesni-intel_glue.c             |23.9%   623|22.2%  36|15.0%  240
arch/x86/crypto/blake2s-glue.c                 |50.0%    28|50.0%   2|16.7%   30
arch/x86/crypto/chacha_glue.c                  | 0.0%   157| 0.0%  10| 0.0%   80
<truncated>
virt/lib/irqbypass.c                           | 0.0%   137| 0.0%   6| 0.0%   88
================================================================================
                                         Total:| 6.0% 1369k| 9.6%  0M| 3.7% 764k
```
### HTML
The `lcov` tool `genhtml` is used to generate html. To create html with the
default settings:

```
$ genhtml --branch-coverage -o html cov.info
```

The page can be viewed at `html/index.html`.

Options of interest:
 * `--frame`: Creates a left hand macro view in a source file view.
 * `--missed`: Helpful if you want to sort by what source is missing the most
   as opposed to the default coverage percentages.
