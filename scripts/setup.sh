#!/usr/bin/env zsh

# Grabs the directory where the script is defined, not where it's run from
script_dir="$(cd $(dirname "${(%):-%x}") && pwd)"

# Get the project root directory (parent of scripts directory)
dev_env_root="$(cd "$script_dir/.." && pwd)"

dry="0"

# Parse command line arguments and set dry run mode if the --dry flag is provided
while [[ $# > 0 ]]; do
    if [[ "$1" == "--dry" ]]; then
        dry="1"
    fi
    shift
done


# Logging function that respects dry run mode
log() {
    if [[ $dry == "1" ]]; then
        echo "[DRY_RUN]: $@"
    else
        echo "$@"
    fi
}

# Execute a command, respecting dry run mode
execute() {
    log "execute: $@"
    if [[ $dry == "1" ]]; then
        return
    fi

    "$@"
}


log "

██████╗ ███████╗██╗   ██╗    ███████╗███████╗████████╗██╗   ██╗██████╗ 
██╔══██╗██╔════╝██║   ██║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗
██║  ██║█████╗  ██║   ██║    ███████╗█████╗     ██║   ██║   ██║██████╔╝
██║  ██║██╔══╝  ╚██╗ ██╔╝    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ 
██████╔╝███████╗ ╚████╔╝     ███████║███████╗   ██║   ╚██████╔╝██║     
╚═════╝ ╚══════╝  ╚═══╝      ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝                                                                     
                                                        
"


# Set config directory
: "${CONFIG_HOME:=$HOME/.config}"

# Change to project root directory
execute cd "$dev_env_root"
# Function to copy directories from source to destination
copy_dir() {
    local from="$1"
    local to="$2"
    
    log "Copying directories from $from to $to"
    
    # Use pushd to change directory and save current location
    pushd "$from" > /dev/null
    
    # Find all directories at depth 1
    local dirs=($(find . -maxdepth 1 -mindepth 1 -type d))
    
    # Loop through each directory
    for dir in "${dirs[@]}"; do
        # Skip unwanted directories (when operating from project root)
        case "$dir" in "./.git"|"./scripts"|"./zsh")
                log "Skipping directory: $dir"
                continue
                ;;
        esac
        
        local dir_name="${dir#./}"  # Remove ./ prefix
        local target_path="$to/$dir_name"
        log "Processing directory: $dir -> $target_path"
        
        # Remove existing directory from the target if it exists
        execute rm -rf "$target_path"
        
        # Copy the directory to the target location
        execute cp -r "$dir" "$to/$dir_name"
    done
    
    # Return to previous directory
    popd > /dev/null
}

# Function to copy a single file from source to destination
copy_file() {
    local from="$1"
    local to="$2"
    local name="$(basename "$from")"
    local target_path="$to/$name"
    
    log "Copying file: $from -> $target_path"
    
    # Remove existing file if it exists
    execute rm -f "$target_path"
    
    # Copy the file
    execute cp "$from" "$target_path"
}

# Copy configuration directories
copy_dir "config" "$CONFIG_HOME"

# Copy individual files
copy_file "config/zsh/.zshrc" "$HOME"