#!/bin/bash

set -euo pipefail

readonly COLOR_RESET='\033[0m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_BOLD='\033[1m'

BASE_DIR="."
DRY_RUN=false
USE_STDIN=false
INPUT_FILE=""


print_msg() {
    local color="$1"
    local msg="$2"
    echo -e "${color}${msg}${COLOR_RESET}"
}

print_action() {
    local type="$1"
    local path="$2"
    local color=""
    local label=""
    
    if [[ "$type" == "dir" ]]; then
        color="$COLOR_GREEN"
        label="[DIR ]"
    else
        color="$COLOR_CYAN"
        label="[FILE]"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        color="$COLOR_YELLOW"
    fi
    
    print_msg "$color" "${label} ${path}"
}

print_error() {
    print_msg "$COLOR_RED" "ERROR: $1" >&2
}

validate_path() {
    local path="$1"
    
    if [[ "$path" == *".."* ]]; then
        print_error "Path contains '..' which is not allowed: $path"
        return 1
    fi
    
    if [[ "$path" == /* ]]; then
        print_error "Absolute paths are not allowed: $path"
        return 1
    fi
    
    return 0
}

create_directory() {
    local dir_path="$1"
    
    if ! validate_path "$dir_path"; then
        return 1
    fi
    
    print_action "dir" "$dir_path"
    
    if [[ "$DRY_RUN" == false ]]; then
        mkdir -p "$dir_path"
    fi
}

create_file() {
    local file_path="$1"
    
    if ! validate_path "$file_path"; then
        return 1
    fi
    
    print_action "file" "$file_path"
    
    if [[ "$DRY_RUN" == false ]]; then
        local parent_dir
        parent_dir="$(dirname "$file_path")"
        if [[ ! -d "$parent_dir" ]]; then
            mkdir -p "$parent_dir"
        fi
        touch "$file_path"
    fi
}

get_indent_level() {
    local line="$1"
    local spaces="${line%%[! ]*}"
    echo $((${#spaces} / 2))
}

strip_tree_chars() {
    local line="$1"
    line="${line//│/}"
    line="${line//├──/}"
    line="${line//└──/}"
    line="${line//├─/}"
    line="${line//└─/}"
    line="${line//├/}"
    line="${line//└/}"
    line="${line//─/}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    echo "$line"
}

is_directory() {
    local name="$1"
    [[ "$name" == */ ]]
}

parse_tree() {
    local input="$1"
    local -a path_stack=()
    local -a depth_stack=() 
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// }" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        local raw_prefix="${line%%[^[:space:]│├└─]*}"
        local indent_len=${#raw_prefix}
        
        local clean_name=$(echo "$line" | sed 's/^[[:space:]│├└─]*//;s/[[:space:]]*$//')
        [[ -z "$clean_name" ]] && continue

        while [[ ${#depth_stack[@]} -gt 0 ]]; do
            local last_idx=$((${#depth_stack[@]} - 1))
            if [[ $indent_len -le ${depth_stack[$last_idx]} ]]; then
                unset 'path_stack[$last_idx]'
                unset 'depth_stack[$last_idx]'
                path_stack=("${path_stack[@]}")
                depth_stack=("${depth_stack[@]}")
            else
                break
            fi
        done

        local current_path="$BASE_DIR"
        for part in "${path_stack[@]}"; do
            current_path="${current_path%/}/$part"
        done
        current_path="${current_path%/}/$clean_name"

        if [[ "$clean_name" == */ ]]; then
            create_directory "$current_path"
            path_stack+=("${clean_name%/}") # Store without trailing slash
            depth_stack+=("$indent_len")
        else
            create_file "$current_path"
        fi

    done <<< "$input"
}

show_help() {
    cat << 'EOF'
mkstruct - Create folder and file structures from text representations

USAGE:
    mkstruct <file>                    Create structure from file
    mkstruct <file> --base <path>      Create in specified directory
    mkstruct <file> --dry-run          Show what would be created
    mkstruct --stdin                   Read structure from stdin
    mkstruct --help                    Show this help

OPTIONS:
    --base <path>     Base directory for creation (default: current directory)
    --dry-run         Show actions without creating files/folders
    --stdin           Read structure from stdin instead of file
    --help            Show this help message

INPUT FORMATS:
    1. Simple indentation (2 spaces per level):
        project/
          src/
            main.cpp
          README.md

    2. Tree-style:
        project/
        ├── src/
        │   └── main.cpp
        └── README.md

FEATURES:
    • Automatic format detection
    • Safe path handling (no .. escapes)
    • Colored output
    • Comment support (lines starting with #)
    • Dry-run mode for testing

EXAMPLES:
    mkstruct structure.txt
    mkstruct tree.txt --base ./myproject
    mkstruct layout.txt --dry-run
    cat structure.txt | mkstruct --stdin
    tree -F | mkstruct --stdin --base ./copy

EOF
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --base)
                if [[ -z "${2:-}" ]]; then
                    print_error "--base requires a path argument"
                    exit 1
                fi
                BASE_DIR="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --stdin)
                USE_STDIN=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                if [[ -n "$INPUT_FILE" ]]; then
                    print_error "Multiple input files specified"
                    exit 1
                fi
                INPUT_FILE="$1"
                shift
                ;;
        esac
    done
    
    if [[ "$USE_STDIN" == false ]] && [[ -z "$INPUT_FILE" ]]; then
        print_error "No input file specified"
        echo "Use --help for usage information"
        exit 1
    fi
    
    if [[ "$USE_STDIN" == true ]] && [[ -n "$INPUT_FILE" ]]; then
        print_error "Cannot specify both --stdin and input file"
        exit 1
    fi
    
    if [[ "$USE_STDIN" == false ]] && [[ ! -f "$INPUT_FILE" ]]; then
        print_error "Input file not found: $INPUT_FILE"
        exit 1
    fi
    
    if [[ "$DRY_RUN" == false ]] && [[ "$BASE_DIR" != "." ]] && [[ ! -d "$BASE_DIR" ]]; then
        mkdir -p "$BASE_DIR"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        print_msg "$COLOR_YELLOW" "=== DRY RUN MODE ==="
    fi
    print_msg "$COLOR_BOLD" "Creating structure in: $BASE_DIR"
    echo
    
    local input_content
    if [[ "$USE_STDIN" == true ]]; then
        input_content=$(cat)
    else
        input_content=$(cat "$INPUT_FILE")
    fi
    
    parse_tree "$input_content"
    
    echo
    if [[ "$DRY_RUN" == true ]]; then
        print_msg "$COLOR_YELLOW" "=== DRY RUN COMPLETE (no files created) ==="
    else
        print_msg "$COLOR_GREEN" "Structure created successfully"
    fi
}

main "$@"
