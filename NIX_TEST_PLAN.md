# Testing the Nix Build on NixOS 25.11

This document provides a comprehensive test plan for verifying that the Flightmare Nix flake works correctly on NixOS 25.11.

## Prerequisites

- NixOS 25.11 or a system with Nix 2.18+ installed
- Flakes enabled in your Nix configuration
- Git installed

## Quick Start Test

Run these commands in order to quickly verify the build:

```bash
# 1. Clone the repository
git clone https://github.com/fluxoz/Flightmare-Reinforcement-Learning.git
cd Flightmare-Reinforcement-Learning

# 2. Check your setup
./nix-build.sh check

# 3. Build the packages
./nix-build.sh build

# 4. Test the installation
./nix-build.sh test

# 5. Enter development shell and verify manually
nix develop
python ./validate_install.py
```

If all these steps complete successfully, the build is working!

## Detailed Test Steps

### Test 1: Nix Configuration Check

**Purpose:** Verify that Nix and flakes are properly configured.

```bash
./nix-build.sh check
```

**Expected Output:**
```
✓ Nix is installed
✓ Nix flakes are enabled
✓ All checks passed! Ready to build.
```

**Troubleshooting:**
- If "Nix flakes are not enabled", add to `/etc/nix/nix.conf`:
  ```
  experimental-features = nix-command flakes
  ```
  Then: `sudo systemctl restart nix-daemon`

### Test 2: Build flightlib (C++ Library)

**Purpose:** Verify that the C++ library with Python bindings builds correctly.

```bash
nix build .#flightlib --print-build-logs
```

**Expected:** Build completes without errors. Check for:
- CMake finds all dependencies (Eigen, OpenCV, ZeroMQ, yaml-cpp)
- No network access errors
- Python bindings compile successfully
- Result symlink created: `result` -> `/nix/store/...`

**Common Issues:**
- **CMake downloads dependencies:** This shouldn't happen. Check that EIGEN_FROM_SYSTEM=ON is set.
- **Missing dependencies:** Ensure all dependencies are in the flake's buildInputs.
- **OpenMP not found (macOS):** This is expected; OpenMP is Linux-only in the flake.

### Test 3: Build flightrl_v2 (Python Package)

**Purpose:** Verify that the RL framework builds correctly.

```bash
nix build .#flightrl_v2 --print-build-logs
```

**Expected:** Build completes without errors. Check for:
- All Python dependencies installed
- Package structure is correct
- No import errors during build

### Test 4: Build Complete Environment

**Purpose:** Build the full Python environment with both packages.

```bash
nix build --print-build-logs
```

**Expected:** 
- Both flightlib and flightrl_v2 are built
- Result is a Python environment with both packages available

### Test 5: Development Shell

**Purpose:** Verify the development environment works.

```bash
nix develop
```

**In the shell, run:**
```bash
# Check environment
echo $FLIGHTMARE_PATH
python --version

# Verify imports
python -c "import flightgym; print('FlightGym OK')"
python -c "import flightrl_v2; print(f'flightrl_v2 {flightrl_v2.__version__}')"

# Run validation
python ./validate_install.py
```

**Expected Output:**
```
Flightmare development environment
Python: Python 3.11.x
FLIGHTMARE_PATH: /path/to/repo

FlightGym OK
flightrl_v2 2.0.0

============================================================
Flightmare Package Validation
============================================================

Core Packages:
------------------------------------------------------------
  ✓ flightgym (version: unknown)
  ✓ flightrl_v2 (version: 2.0.0)

Dependencies:
------------------------------------------------------------
  ✓ numpy (version: x.x.x)
  ✓ torch (version: x.x.x)
  ... (all dependencies listed)

flightrl_v2 Components:
------------------------------------------------------------
  ✓ flightrl_v2.core (version: 2.0.0)
  ... (all components listed)

Summary:
  Core packages: 2/2
  Dependencies: x/12
  Components: 7/7

✓ All core packages are installed correctly!
✓ All flightrl_v2 components are available!
```

### Test 6: Import Test

**Purpose:** Detailed check of all imports.

```bash
nix develop --command python -c "
from flightrl_v2 import (
    BaseFlightEnv,
    BaseTask,
    TaskConfig,
    FlightEnvVec,
    make_flight_env_for_sb3,
    HoverTask,
    TargetReachingTask,
    train_sac,
    evaluate_policy,
)
print('All imports successful!')
"
```

**Expected:** "All imports successful!"

### Test 7: Quick Training Test

**Purpose:** Verify that training actually works.

```bash
nix develop
cd flightrl_v2/examples
python 01_basic_training.py --timesteps 1000
```

**Expected:**
- Script runs without errors
- Training progress is displayed
- Model is saved
- No crashes or segfaults

**Note:** This requires flightgym (C++ library) to work correctly.

### Test 8: Run via Nix Run

**Purpose:** Test the packaged applications.

```bash
# Run Python interpreter
nix run

# Run training app (if available)
nix run .#train -- --timesteps 1000
```

**Expected:** Applications run without import errors.

## Common Build Issues and Solutions

### Issue: "error: hash mismatch in fixed-output derivation"

**Cause:** SHA256 hash for a Python package doesn't match.

**Solution:** Update the hash in `flake.nix`. Run:
```bash
nix-prefetch-url --type sha256 --unpack <package-url>
```
Then update the corresponding sha256 field in the flake.

### Issue: "CMake Error: Could not find Eigen3"

**Cause:** Eigen is not being found by CMake.

**Solution:** 
1. Check that `eigen` is in `buildInputs` in the flake
2. Verify that `EIGEN_FROM_SYSTEM=ON` is set in `cmakeFlags`
3. Check that `CMAKE_PREFIX_PATH` includes the Eigen path

### Issue: "undefined symbol: _ZN2cv..."

**Cause:** OpenCV version mismatch or linking issue.

**Solution:**
1. Ensure OpenCV is in `buildInputs`
2. Check that the OpenCV version in nixpkgs is compatible
3. Try rebuilding with `--option pure-eval false`

### Issue: "ImportError: cannot import name 'flightgym'"

**Cause:** The C++ Python extension didn't build correctly.

**Solution:**
1. Check the build logs for flightlib
2. Ensure pybind11 is in `propagatedBuildInputs`
3. Verify that the .so file was created and installed

### Issue: Build tries to download dependencies

**Cause:** CMake is trying to fetch external dependencies.

**Solution:**
1. Verify EIGEN_FROM_SYSTEM option is ON
2. Check that all dependencies are provided by Nix
3. The flake should patch setup.py to prevent downloads

## Success Criteria

The Nix build is considered successful if:

1. ✅ All build steps complete without errors
2. ✅ `./nix-build.sh test` passes all checks
3. ✅ `python ./validate_install.py` shows all core packages working
4. ✅ Can import both `flightgym` and `flightrl_v2` in the dev shell
5. ✅ Can run a training example without crashes
6. ✅ No network access errors during build
7. ✅ Build is reproducible (running again produces same result)

## Reporting Issues

If you encounter issues, please report:

1. **NixOS version:** `nixos-version` or `nix --version`
2. **System:** `uname -a`
3. **Error message:** Full error from build logs
4. **Build command:** The exact command that failed
5. **Build logs:** Use `--print-build-logs` to capture full output

Create an issue with this information, or add it as a comment to the PR.

## Next Steps After Successful Build

Once the build works:

1. **Generate flake.lock:** `nix flake update` (this pins dependencies)
2. **Test on different systems:** Try on x86_64-linux, aarch64-linux, etc.
3. **Add to NixOS configuration:** See NIX_BUILD.md for system-wide installation
4. **Share results:** Comment on the PR that the build works on NixOS 25.11

## Additional Resources

- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [Nixpkgs Python Documentation](https://nixos.org/manual/nixpkgs/stable/#python)
- [Flake schema](https://nixos.wiki/wiki/Flakes)
- [NIX_BUILD.md](./NIX_BUILD.md) - Complete Nix documentation for this project
