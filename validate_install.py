#!/usr/bin/env python3
"""
Validation script for Flightmare packages.
This script checks that the packages are correctly installed and can be imported.
"""
import sys
import importlib
from typing import List, Tuple

def check_import(module_name: str) -> Tuple[bool, str]:
    """
    Try to import a module and return success status and message.
    
    Args:
        module_name: Name of the module to import
        
    Returns:
        Tuple of (success, message)
    """
    try:
        module = importlib.import_module(module_name)
        version = getattr(module, '__version__', 'unknown')
        return True, f"✓ {module_name} (version: {version})"
    except ImportError as e:
        return False, f"✗ {module_name} - ImportError: {e}"
    except Exception as e:
        return False, f"✗ {module_name} - Error: {e}"

def main():
    """Run all validation checks."""
    print("=" * 60)
    print("Flightmare Package Validation")
    print("=" * 60)
    print()
    
    # Core packages
    print("Core Packages:")
    print("-" * 60)
    core_checks = [
        ('flightgym', True),  # Required
        ('flightrl_v2', True),  # Required
    ]
    
    core_passed = 0
    for module, required in core_checks:
        success, message = check_import(module)
        print(f"  {message}")
        if success:
            core_passed += 1
        elif required:
            print(f"    ERROR: Required package {module} is missing!")
    
    print()
    
    # Dependencies
    print("Dependencies:")
    print("-" * 60)
    dep_checks = [
        ('numpy', True),
        ('torch', True),
        ('gymnasium', True),
        ('stable_baselines3', True),
        ('matplotlib', False),
        ('tensorboard', False),
        ('ruamel.yaml', True),
        ('pandas', False),
        ('PIL', False),  # Pillow
        ('plotly', False),
        ('tqdm', False),
        ('imageio', False),
    ]
    
    deps_passed = 0
    for module, required in dep_checks:
        success, message = check_import(module)
        print(f"  {message}")
        if success:
            deps_passed += 1
        elif required:
            print(f"    WARNING: Recommended package {module} is missing")
    
    print()
    
    # Check flightrl_v2 components
    print("flightrl_v2 Components:")
    print("-" * 60)
    component_checks = [
        'flightrl_v2.core',
        'flightrl_v2.envs',
        'flightrl_v2.tasks',
        'flightrl_v2.algorithms',
        'flightrl_v2.configs',
        'flightrl_v2.tools',
        'flightrl_v2.visualization',
    ]
    
    components_passed = 0
    for module in component_checks:
        success, message = check_import(module)
        print(f"  {message}")
        if success:
            components_passed += 1
    
    print()
    print("=" * 60)
    print("Summary:")
    print(f"  Core packages: {core_passed}/{len(core_checks)}")
    print(f"  Dependencies: {deps_passed}/{len(dep_checks)}")
    print(f"  Components: {components_passed}/{len(component_checks)}")
    
    total = core_passed + deps_passed + components_passed
    total_max = len(core_checks) + len(dep_checks) + len(component_checks)
    
    print()
    if core_passed == len(core_checks):
        print("✓ All core packages are installed correctly!")
        if components_passed == len(component_checks):
            print("✓ All flightrl_v2 components are available!")
        print()
        print("You can now use Flightmare:")
        print("  python -c 'from flightrl_v2 import make_flight_env_for_sb3'")
        print()
        return 0
    else:
        print("✗ Some core packages are missing. Please check the installation.")
        print()
        return 1

if __name__ == '__main__':
    sys.exit(main())
