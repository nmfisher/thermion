#!/usr/bin/env python3
"""
Compare PNG files between golden reference images and test output images.
"""

import os
import sys
from pathlib import Path
from PIL import Image, ImageChops
import numpy as np

def calculate_image_difference(img1_path, img2_path):
    """
    Calculate the difference between two images.
    Returns a tuple of (mean_squared_error, max_difference, are_identical)
    """
    try:
        with Image.open(img1_path) as img1, Image.open(img2_path) as img2:
            # Convert to same mode if different
            if img1.mode != img2.mode:
                img1 = img1.convert('RGBA')
                img2 = img2.convert('RGBA')
            
            # Check if dimensions match
            if img1.size != img2.size:
                print(f"Size mismatch: {img1_path} {img1.size} vs {img2_path} {img2.size}")
                return None, None, False
            
            # Calculate difference
            diff = ImageChops.difference(img1, img2)
            
            # Convert to numpy for calculations
            diff_array = np.array(diff)
            
            # Calculate metrics
            mse = np.mean(diff_array ** 2)
            max_diff = np.max(diff_array)
            are_identical = mse == 0
            
            return mse, max_diff, are_identical
            
    except Exception as e:
        print(f"Error comparing {img1_path} and {img2_path}: {e}")
        return None, None, False

def find_png_files(directory):
    """Find all PNG files in a directory recursively."""
    png_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.lower().endswith('.png'):
                png_files.append(os.path.relpath(os.path.join(root, file), directory))
    return sorted(png_files)

def main():
    # Define paths
    golden_dir = Path("golden-downloads/thermion_dart/test/output")
    output_dir = Path("output")
    
    # Check if directories exist
    if not golden_dir.exists():
        print(f"Error: Golden directory not found: {golden_dir}")
        sys.exit(1)
    
    if not output_dir.exists():
        print(f"Error: Output directory not found: {output_dir}")
        sys.exit(1)
    
    # Find PNG files in both directories
    golden_files = find_png_files(golden_dir)
    output_files = find_png_files(output_dir)
    
    print(f"Found {len(golden_files)} golden files and {len(output_files)} output files")
    
    # Track comparison results
    identical_count = 0
    different_count = 0
    missing_count = 0
    error_count = 0
    
    # Compare each golden file with its corresponding output file
    for golden_file in golden_files:
        golden_path = golden_dir / golden_file
        output_path = output_dir / golden_file
        
        if not output_path.exists():
            print(f"❌ MISSING: {golden_file} (exists in golden but not in output)")
            missing_count += 1
            continue
        
        mse, max_diff, are_identical = calculate_image_difference(golden_path, output_path)
        
        if mse is None:
            print(f"❌ ERROR: {golden_file} (failed to compare)")
            error_count += 1
            continue
        
        if are_identical:
            print(f"✅ IDENTICAL: {golden_file}")
            identical_count += 1
        else:
            print(f"⚠️  DIFFERENT: {golden_file} (MSE: {mse:.2f}, Max diff: {max_diff})")
            different_count += 1
    
    # Check for files that exist in output but not in golden
    extra_files = set(output_files) - set(golden_files)
    for extra_file in extra_files:
        print(f"ℹ️  EXTRA: {extra_file} (exists in output but not in golden)")
    
    # Print summary
    print("\n" + "="*50)
    print("COMPARISON SUMMARY:")
    print(f"✅ Identical files: {identical_count}")
    print(f"⚠️  Different files: {different_count}")
    print(f"❌ Missing files: {missing_count}")
    print(f"❌ Error files: {error_count}")
    print(f"ℹ️  Extra files: {len(extra_files)}")
    print(f"📊 Total golden files: {len(golden_files)}")
    
    # Exit with appropriate code
    if different_count > 0 or missing_count > 0 or error_count > 0:
        print("\n❌ COMPARISON FAILED")
        sys.exit(1)
    else:
        print("\n✅ ALL COMPARISONS PASSED")
        sys.exit(0)

if __name__ == "__main__":
    main()
