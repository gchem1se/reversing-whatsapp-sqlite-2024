#!/bin/bash

# Define the path to the mkdocs.yml file
MKDOCS_FILE="mkdocs.yml"

# Check if mkdocs.yml exists
if [ ! -f "$MKDOCS_FILE" ]; then
  echo "mkdocs.yml not found in the current directory."
  exit 1
fi

# Get the nav section lines from mkdocs.yml
nav_start=$(grep -n "^nav:" "$MKDOCS_FILE" | cut -d: -f1)
if [ -z "$nav_start" ]; then
  echo "nav section not found in mkdocs.yml."
  exit 1
fi

# Function to add a new entry to mkdocs.yml
add_to_nav() {
  local filename=$1
  local basename=$(basename "$filename" .md)
  # Append the new entry in the nav section of mkdocs.yml
  sed -i "${nav_start}a\ \ - ${basename^}: ${basename^}" "$MKDOCS_FILE"
  echo "Added $filename to mkdocs.yml under nav."
}

# Iterate over all .md files in the current directory
for file in ./docs/*.md; do
  basename=$(basename "$file" .md)
  # Skip if there are no .md files
  [ -e "$file" ] || continue

  # Check if the file is already in the mkdocs.yml nav
  if ! grep -q "$basename" "$MKDOCS_FILE"; then
    add_to_nav "$file"
  else
    echo "$basename already exists in the mkdocs.yml nav section."
  fi
done
