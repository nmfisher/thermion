#!/bin/bash
set -e

echo "Running post-create setup..."

# Ensure Flutter is on PATH and working
flutter doctor -v

echo "Post-create setup complete."
