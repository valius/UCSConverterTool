# Define variables
FLUTTER = flutter
PROJECT_NAME = UCSConverterTool

# Default target
all: help

# Help target
help:
	@echo "Makefile for Flutter project:"
	@echo "Usage:"
	@echo "    make run_windows_debug       - Run on Windows (Debug)"
	@echo "    make run_linux_debug         - Run on Linux (Debug)"
	@echo "    make run_macos_debug         - Run on Mac OS (Debug)"
	@echo "    make build_windows_debug     - Build for Windows (Debug)"
	@echo "    make build_linux_debug       - Build for Linux (Debug)"
	@echo "    make build_macos_debug       - Build for Mac OS (Debug)"
	@echo "    make run_windows        		- Run on Windows"
	@echo "    make run_linux          		- Run on Linux"
	@echo "    make run_macos          		- Run on Mac OS"
	@echo "    make build_windows      		- Build for Windows"
	@echo "    make build_linux        		- Build for Linux"
	@echo "    make build_macos        		- Build for Mac OS"
	@echo "    make clean              		- Clean the project"
	@echo "    make test               		- Run unit tests"
	@echo "    make analyze            		- Analyze the code for issues"
	@echo "    make format             		- Format the Dart code"
	@echo "    make pub_get            		- Install dependencies"
	@echo "    make upgrade_deps       		- Upgrade all dependencies"

# Run the Flutter app on Windows
run_windows_debug:
	$(FLUTTER) run -d windows

# Run the Flutter app on Linux
run_linux_debug:
	$(FLUTTER) run -d linux

# Run the Flutter app on Mac OS
run_macos_debug:
	$(FLUTTER) run -d macos

# Run the Flutter app on Windows
run_windows:
	$(FLUTTER) run -d windows

# Run the Flutter app on Linux
run_linux:
	$(FLUTTER) run -d linux

# Run the Flutter app on Mac OS
run_macos:
	$(FLUTTER) run -d macos

# Build the Flutter app for Windows
build_windows_debug:
	$(FLUTTER) build windows

# Build the Flutter app for Linux
build_linux_debug:
	$(FLUTTER) build linux

# Build the Flutter app for Mac OS
build_macos_debug:
	$(FLUTTER) build macos

# Build the Flutter app for Windows
build_windows:
	$(FLUTTER) build windows --release

# Build the Flutter app for Linux
build_linux:
	$(FLUTTER) build linux --release

# Build the Flutter app for Mac OS
build_macos:
	$(FLUTTER) build macos --release

# Clean build and temporary files
clean:
	$(FLUTTER) clean

# Run tests
test:
	$(FLUTTER) test

# Analyze code
analyze:
	$(FLUTTER) analyze

# Format code
format:
	$(FLUTTER) format .

# Install dependencies
pub_get:
	$(FLUTTER) pub get

# Upgrade dependencies
upgrade_deps:
	$(FLUTTER) pub upgrade
