# Building and Running Flightmare with Nix

This repository includes a Nix flake for building and running Flightmare on NixOS and other systems with Nix installed.

## Quick Start

### Prerequisites

- NixOS 25.11 or later, or any system with Nix installed
- Nix flakes enabled (add `experimental-features = nix-command flakes` to `/etc/nix/nix.conf`)
- CMake 3.10 or later (automatically provided by Nix)

### Building

```bash
# Clone the repository
git clone https://github.com/fluxoz/Flightmare-Reinforcement-Learning.git
cd Flightmare-Reinforcement-Learning

# Build the project
nix build

# Or enter a development shell
nix develop
```

### Running

```bash
# Run Python with flightmare installed
nix run

# Or use the training app
nix run .#train -- --timesteps 10000

# In development shell
nix develop
python -c "import flightgym; print('FlightGym loaded successfully')"
python -c "import flightrl_v2; print(f'flightrl_v2 version: {flightrl_v2.__version__}')"
```

## What the Flake Provides

### Packages

- `default` / `flightmare`: Complete Python environment with flightlib and flightrl_v2
- `flightlib`: C++ physics engine with Python bindings (flightgym)
- `flightrl_v2`: Modern RL framework

### Development Shell

The development shell (`nix develop`) includes:

- All C++ dependencies (Eigen, OpenCV, ZeroMQ, yaml-cpp, etc.)
- Python 3.11 with all required packages
- Build tools (CMake, GCC, pkg-config)
- Development utilities

### Apps

- `default`: Python interpreter with flightmare installed
- `train`: Quick training script launcher

## Building Individual Components

```bash
# Build only flightlib
nix build .#flightlib

# Build only flightrl_v2
nix build .#flightrl_v2
```

## Development Workflow

### Enter Development Environment

```bash
nix develop
```

This will:
- Set `FLIGHTMARE_PATH` to the current directory
- Configure Python environment
- Make all dependencies available

### Make Changes and Test

```bash
# In the development shell
cd flightlib
python setup.py develop  # For development mode

cd ../flightrl_v2
python setup.py develop

# Run tests
cd ../flightrl_v2
pytest tests/
```

### Training Example

```bash
nix develop
cd flightrl_v2/examples
python 01_basic_training.py --timesteps 10000
```

## Troubleshooting

### Network Access During Build

If you see errors about network access or downloading dependencies during the build:

The Nix build system is sandboxed and doesn't allow network access during builds. The flake is configured to use system-provided packages instead of downloading them. If you still encounter these issues:

1. Make sure you're using a recent version of nixpkgs (the flake uses `nixos-unstable`)
2. Check that all dependencies are properly listed in the flake
3. The flake patches the CMakeLists.txt to prefer system packages

If the build tries to download Eigen, pybind11, or yaml-cpp:
- These should be provided by Nix
- The `EIGEN_FROM_SYSTEM` CMake option is set to ON
- Tests are disabled to avoid additional downloads

### Hash Mismatch for Python Packages

If you encounter hash mismatches for `sb3-contrib` or `plotly`, you'll need to update the SHA256 hashes in `flake.nix`. Run:

```bash
nix-prefetch-url --type sha256 --unpack https://files.pythonhosted.org/packages/source/s/sb3-contrib/sb3-contrib-2.2.1.tar.gz
nix-prefetch-url --type sha256 --unpack https://files.pythonhosted.org/packages/source/p/plotly/plotly-5.18.0.tar.gz
```

Then update the `sha256` fields in `flake.nix` with the output.

### OpenMP Issues on macOS

On macOS, OpenMP might not be available. The flake handles this by conditionally including OpenMP only on Linux systems.

### CMake Can't Find Dependencies

If CMake can't find dependencies during build, check that:
1. All dependencies are listed in `buildInputs` in the flake
2. The `NIX_CFLAGS_COMPILE` environment variable includes necessary include paths

### Missing Python Packages

Some Python packages might not be available in nixpkgs. You can:

1. Add them to the flake as custom packages (see `sb3-contrib` example)
2. Use pip in a development environment (less reproducible)
3. Override packages from nixpkgs

## Using with Other Projects

You can use this flake as a dependency in your own flake:

```nix
{
  inputs = {
    flightmare.url = "github:fluxoz/Flightmare-Reinforcement-Learning";
  };

  outputs = { self, flightmare, ... }: {
    # Use flightmare.packages.${system}.default
  };
}
```

## NixOS Configuration

To add Flightmare to your NixOS system:

```nix
# configuration.nix
{ config, pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.callPackage /path/to/flightmare/flake.nix {}).packages.${pkgs.system}.default
  ];
}
```

Or use it in your home-manager configuration:

```nix
# home.nix
{ config, pkgs, ... }:

{
  home.packages = [
    inputs.flightmare.packages.${pkgs.system}.default
  ];
}
```

## Additional Resources

- [Flightmare README](./README.md)
- [flightrl_v2 Documentation](./flightrl_v2/README.md)
- [Docker Build System](./docker/README.md)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Flakes Guide](https://nixos.wiki/wiki/Flakes)

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE) for details.
