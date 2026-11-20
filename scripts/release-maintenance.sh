#!/bin/bash
#
# A script to automate release maintenance for Rancher docs.
#
# This script updates multiple AsciiDoc files with new version information.

set -o errexit
set -o nounset
set -o pipefail

# --- Configuration ---
# Base path to the documentation repository.
# The script assumes it is located in the root of the docs repository.
# It determines its own location to make the path portable.
DOCS_REPO_PATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DOCS_REPO_PATH=${DOCS_REPO_PATH%/scripts}

# --- Global Variables ---
VERSION=""
RELEASE_DATE=""
ADAPTER_VERSION=""
WEBHOOK_VERSION=""
TURTLES_VERSION=""
FLEET_VERSION=""
NEW_CURRENT_PRIME_AVAIL="y"
NEW_CURRENT_COMMUNITY_AVAIL="y"

# --- Functions ---

# Print usage information and exit.
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

This script automates the process of release maintenance for Rancher docs.

Examples:
  Provide a version to automatically fetch component versions from the release branch in rancher/charts:
    $ ./scripts/$(basename "$0") -v v2.15.3 -d "2026-11-03"

  Or, provide the version and component versions manually:
    $ ./scripts/$(basename "$0") -v v2.15.3 -d "2026-10-28" -a 110.0.1+up10.0.1 -w 0.11.4 -T 110.0.4+up0.27.4-rc.0 -F 110.0.3+up0.16.3-rc.2

Options:
  -v <version>          The new Rancher version (e.g., v2.15.3). (Required)
  -d <date>             The release date (e.g., "2026-11-03"). (Required)
  -a <adapter_version>  The corresponding CSP adapter version (e.g., 110.0.1+up10.0.1). (Required for manual mode in v2.15 and earlier)
  -w <webhook_version>  The corresponding webhook version (e.g., 0.11.4). (Required for manual mode)
  -T <turtles_version>  The corresponding Turtles version. (Required for manual mode)
  -F <fleet_version>    The corresponding Fleet version. (Required for manual mode)

  --prime [y/n]         Is this version available in Prime? (Default: y)
  --community [y/n]     Is this version available in Community? (Default: y)
  -h, --help            Display this help message and exit.
EOF
  exit "${1:-1}"
}

# Parse command-line arguments.
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -v) VERSION="$2"; shift 2 ;;
      -d) RELEASE_DATE="$2"; shift 2 ;;
      -a) ADAPTER_VERSION="$2"; shift 2 ;;
      -w) WEBHOOK_VERSION="$2"; shift 2 ;;
      -T) TURTLES_VERSION="$2"; shift 2 ;;
      -F) FLEET_VERSION="$2"; shift 2 ;;
      --prime) NEW_CURRENT_PRIME_AVAIL="$2"; shift 2 ;;
      --community) NEW_CURRENT_COMMUNITY_AVAIL="$2"; shift 2 ;;
      -h|--help) usage 0 ;;
      *) echo "Unknown option: $1"; usage 1 ;;
    esac
  done
}

# Validate that required inputs have been provided and are in the correct format.
validate_inputs() {
  local valid=true
  if [[ -z "$VERSION" ]]; then echo "Error: Version is required. Use -v."; valid=false; fi
  if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "Error: Version format must be vX.Y.Z."; valid=false; fi
  if [[ -z "$RELEASE_DATE" ]]; then echo "Error: Release date is required."; valid=false; fi
  if ! date -d "$RELEASE_DATE" >/dev/null 2>&1; then echo "Error: Invalid date format for '$RELEASE_DATE'."; valid=false; fi

  if ! "$valid"; then
    echo
    usage 1
  fi
}

# Check whether CSP adapter is supported for the given minor version (<= v2.15).
is_csp_adapter_supported() {
  local minor="$1" # e.g. "v2.15" or "v2.16"
  local highest
  highest=$(printf '%s\n%s\n' "$minor" "v2.15" | sort -V | tail -n1)
  [[ "$highest" == "v2.15" ]]
}

# Validate that all component versions are provided in manual mode.
validate_manual_inputs() {
  local minor_ver="$1"
  local valid=true
  if is_csp_adapter_supported "$minor_ver" && [[ -z "$ADAPTER_VERSION" ]]; then
    echo "Error: Adapter version is required for ${minor_ver} when not fetching automatically."; valid=false
  fi
  if [[ -z "$WEBHOOK_VERSION" ]]; then echo "Error: Webhook version is required when not fetching automatically."; valid=false; fi
  if [[ -z "$TURTLES_VERSION" ]]; then echo "Error: Turtles version is required when not fetching automatically."; valid=false; fi
  if [[ -z "$FLEET_VERSION" ]]; then echo "Error: Fleet version is required when not fetching automatically."; valid=false; fi

  if ! "$valid"; then
    echo
    usage 1
  fi
}

# Fetch and parse component versions from rancher/charts repository.
fetch_charts_data() {
  local charts_branch="$1"
  local minor_ver="$2"

  echo "-> Fetching versions from rancher/charts branch: ${charts_branch}..."

  local release_yaml_url="https://raw.githubusercontent.com/rancher/charts/refs/heads/${charts_branch}/release.yaml"
  local release_yaml_content
  release_yaml_content=$(curl -sSfL "$release_yaml_url")
  if [[ $? -ne 0 ]] || [[ -z "$release_yaml_content" ]]; then
    echo "Error: Failed to fetch or empty content from $release_yaml_url" >&2
    exit 1
  fi

  # Extract the first entry for each component from release.yaml
  local webhook_raw fleet_raw turtles_raw
  webhook_raw=$(echo "$release_yaml_content" | awk '/^rancher-webhook:/{p=1; next} p && /^[a-zA-Z0-9_-]+:/{p=0} p && /^[[:space:]]*- /{print $2; exit}')
  fleet_raw=$(echo "$release_yaml_content" | awk '/^fleet:/{p=1; next} p && /^[a-zA-Z0-9_-]+:/{p=0} p && /^[[:space:]]*- /{print $2; exit}')
  turtles_raw=$(echo "$release_yaml_content" | awk '/^rancher-turtles:/{p=1; next} p && /^[a-zA-Z0-9_-]+:/{p=0} p && /^[[:space:]]*- /{print $2; exit}')

  if [[ -z "$webhook_raw" ]]; then
    echo "Error: Could not parse rancher-webhook from release.yaml" >&2
    exit 1
  fi

  # For rancher-webhook: from e.g. 110.0.4+up0.11.4-rc.6 extract 0.11.4
  local webhook_clean="${webhook_raw##*+up}"
  WEBHOOK_VERSION="${webhook_clean%%-rc*}"
  FLEET_VERSION="$fleet_raw"
  TURTLES_VERSION="$turtles_raw"

  echo "  - Found Webhook Version: ${WEBHOOK_VERSION} (from ${webhook_raw})"
  if [[ -n "$TURTLES_VERSION" ]]; then
    echo "  - Found Turtles Version: ${TURTLES_VERSION}"
  fi
  if [[ -n "$FLEET_VERSION" ]]; then
    echo "  - Found Fleet Version: ${FLEET_VERSION}"
  fi

  # CSP adapter is dropped in v2.16+, only extract from index.yaml for <= v2.15
  if is_csp_adapter_supported "$minor_ver"; then
    local index_yaml_url="https://raw.githubusercontent.com/rancher/charts/refs/heads/${charts_branch}/index.yaml"
    echo "-> Fetching rancher-csp-adapter version from rancher/charts index.yaml..."
    local index_yaml_content
    index_yaml_content=$(curl -sSfL "$index_yaml_url")
    if [[ $? -ne 0 ]] || [[ -z "$index_yaml_content" ]]; then
      echo "Error: Failed to fetch or empty content from $index_yaml_url" >&2
      exit 1
    fi

    ADAPTER_VERSION=$(echo "$index_yaml_content" | awk '
      /^  rancher-csp-adapter:/ { in_chart=1; next }
      in_chart && /^  [a-zA-Z0-9_-]+:/ { in_chart=0 }
      in_chart && /^[[:space:]]*version:/ && !ver {
        gsub(/["\047]/, "", $2)
        ver=$2
      }
      END { print ver }
    ')
    if [[ -z "$ADAPTER_VERSION" ]]; then
      echo "Error: Could not parse rancher-csp-adapter version from index.yaml" >&2
      exit 1
    fi
    echo "  - Found Adapter Version: ${ADAPTER_VERSION}"
  else
    echo "  - Skipping Adapter Version (rancher-csp-adapter dropped in ${minor_ver})"
    ADAPTER_VERSION=""
  fi
}

# Execute a command.
run_cmd() {
  ex -s "$1" <<< "$2"
}

# Update the revdate in a given file.
update_revdate() {
  local file="$1"
  local iso_date="$2"
  echo "-> Updating revdate in $file"
  local ex_cmd
  ex_cmd=$(cat <<EOF
%s/^:revdate: .*/:revdate: ${iso_date}/
x
EOF
)
  run_cmd "$file" "$ex_cmd"
}

# Update a specific block in the release-notes.adoc file.
update_release_notes_block() {
  local file="$1"
  local version="$2"
  local new_prime_mark="$3"
  local new_community_mark="$4"
  local current_marker="$5"
  local current_end_marker="$6"
  local past_marker="$7"
  local rn_link="$8"

  # Check if the block exists in the file before trying to update it.
  if ! grep -q "//.*${current_marker}\." "$file"; then
    return 0
  fi

  local current_block
  current_block=$(awk "/\/\/.*${current_end_marker}\./{p=0} /\/\/.*${current_marker}\./{p=1; next} p" "$file")
  
  # Check if the block is empty or contains only whitespace
  if [[ -z "$(echo -n "$current_block" | tr -d '[:space:]')" ]]; then
    current_block=""
  fi

  local past_block=""
  if [[ -n "$current_block" ]]; then
    local old_version
    # Get the first non-empty line to extract the version
    old_version=$(echo "$current_block" | awk 'NF' | head -n 1 | cut -d '|' -f 2 | tr -d ' ')

    if [[ -n "$old_version" ]]; then
      if [[ "$old_version" == *.0 ]]; then
        # Skip updating the support matrix link if the old version is a x.y.0 release.
        past_block=$(echo "$current_block" | awk 'NF')
      else
        # When moving a version to "Past", update its support matrix link from "N/A" to a URL.
        local url_version_part="rancher-$(echo "$old_version" | tr '.' '-')"
        local support_matrix_url="https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/${url_version_part}/"
        local support_matrix_cell="| ${support_matrix_url}[View]"
        # Replace the "| N/A" line for the support matrix with the generated URL.
        # awk 'NF' to remove empty lines before processing with sed
        past_block=$(echo "$current_block" | awk 'NF' | sed "0,/^| N\/A\$/s#^| N/A\$#${support_matrix_cell}#")
      fi
    else
      # Fallback if the old version couldn't be parsed, but still remove empty lines.
      past_block=$(echo "$current_block" | awk 'NF')
    fi
    past_block="${past_block}"$'\n'
  fi

  # Create the new current version entry.
  local new_current_block
  new_current_block=$(cat <<EOF
| ${version}
| ${rn_link}
| N/A
| ${new_prime_mark}
| ${new_community_mark}

EOF
)

  # Atomically update the file: insert past version and replace current version.
  local ex_cmd
  # Only add the past block if it's not empty
  if [[ -n "$past_block" ]]; then
    ex_cmd=$(cat <<EOF
/\/\/.*${past_marker}\./a
${past_block}
.
/\/\/.*${current_marker}\./+1,/\/\/.*${current_end_marker}\./-1d
/\/\/.*${current_marker}\./a
${new_current_block}
.
x
EOF
)
  else
    # If there's no past block to add, just update the current version block.
    ex_cmd=$(cat <<EOF
/\/\/.*${current_marker}\./+1,/\/\/.*${current_end_marker}\./-1d
/\/\/.*${current_marker}\./a
${new_current_block}
.
x
EOF
)
  fi
  run_cmd "$file" "$ex_cmd"
}

# Update the release-notes.adoc file.
update_release_notes() {
  local file="$1"
  local version="$2"
  local new_prime_mark="$3"
  local new_community_mark="$4"

  echo "-> Updating release notes in $file"

  local product_rn_link="xref:release-notes/${version}.adoc[View]"
  if [[ "$version" == *.0 ]]; then
    product_rn_link="https://github.com/rancher/rancher/releases/tag/${version}[GitHub Release]"
  fi

  # Update Product block
  update_release_notes_block "$file" "$version" "$new_prime_mark" "$new_community_mark" \
    "CURRENT VERSION" "CURRENT VERSION END" "PAST VERSIONS" "$product_rn_link"

  # Update Community block
  update_release_notes_block "$file" "$version" "$new_prime_mark" "$new_community_mark" \
    "CURRENT COMMUNITY VERSION" "CURRENT COMMUNITY VERSION END" "PAST COMMUNITY VERSIONS" "https://github.com/rancher/rancher/releases/tag/${version}[GitHub Release]"
}

# Update a simple compatibility matrix file.
update_matrix() {
  local file="$1"
  local header_pattern="$2"
  local new_row="$3"
  
  echo "-> Updating matrix in $file"
  local ex_cmd
  ex_cmd=$(cat <<EOF
/${header_pattern}/a
${new_row}
.
x
EOF
)
  run_cmd "$file" "$ex_cmd"
}

# Update an attribute in antora.yml.
update_antora_attr() {
  local file="$1"
  local attr="$2"
  local value="$3"
  echo "-> Updating $attr in $file"
  local ex_cmd
  if grep -q "^\s*${attr}:" "$file"; then
    ex_cmd=$(cat <<EOF
%s/^\(\s*\)${attr}: .*/\1${attr}: ${value}/
x
EOF
)
  else
    ex_cmd=$(cat <<EOF
/^\s*attributes:/a
    ${attr}: ${value}
.
x
EOF
)
  fi
  run_cmd "$file" "$ex_cmd"
}

# --- Main Logic ---
main() {
  if [[ $# -eq 0 ]]; then
    usage 1
  fi

  parse_args "$@"

  # Sync webhook availability with new version availability. This simplifies input
  # by only requiring one set of availability flags (prime/community).
  local WEBHOOK_PRIME_AVAIL=$NEW_CURRENT_PRIME_AVAIL
  local WEBHOOK_COMMUNITY_AVAIL=$NEW_CURRENT_COMMUNITY_AVAIL

  validate_inputs

  # Prepare variables
  local iso_date
  iso_date=$(date -d "$RELEASE_DATE" "+%Y-%m-%d")
  local version_no_v="${VERSION#v}"
  local minor_version_no_v
  minor_version_no_v=$(echo "$version_no_v" | cut -d. -f1,2)
  local minor_version_with_v="v${minor_version_no_v}"

  # Fetch versions from release branch in rancher/charts, or use manual inputs
  if [[ -z "$ADAPTER_VERSION" ]] && [[ -z "$WEBHOOK_VERSION" ]]; then
    local charts_branch="dev-${minor_version_with_v}"
    fetch_charts_data "$charts_branch" "$minor_version_with_v"
  else
    echo "-> Using manually provided component versions..."
    validate_manual_inputs "$minor_version_with_v"
  fi

  # Calculate final turtles version
  local final_turtles_version=""
  if [[ -n "$TURTLES_VERSION" ]]; then
    local turtles_clean="${TURTLES_VERSION#*+up}"
    turtles_clean=$(echo "$turtles_clean" | cut -d. -f1,2)
    final_turtles_version="v${turtles_clean}"
  fi

  # Calculate final fleet version
  local final_fleet_version=""
  if [[ -n "$FLEET_VERSION" ]]; then
    local fleet_clean="${FLEET_VERSION#*+up}"
    fleet_clean=$(echo "$fleet_clean" | cut -d. -f1,2)
    final_fleet_version="v${fleet_clean}"
  fi

  # Validate Turtles
  if [[ -n "$final_turtles_version" ]]; then
    echo "-> Validating Turtles version ${final_turtles_version}..."
    local turtles_url="https://github.com/rancher/turtles-product-docs/tree/main/versions/${final_turtles_version}"
    local http_status
    http_status=$(curl -s -L -o /dev/null -w "%{http_code}" "$turtles_url")

    if [[ "$http_status" != "200" ]]; then
      echo "Warning: '${final_turtles_version}' not found in Turtles docs repo. Skipping update."
      final_turtles_version=""
    else
      echo "   Confirmed '${final_turtles_version}' exists in Turtles docs repo."
    fi
  fi

  # Validate Fleet
  if [[ -n "$final_fleet_version" ]]; then
    echo "-> Validating Fleet version ${final_fleet_version}..."
    local fleet_url="https://github.com/rancher/fleet-product-docs/tree/product-docs/versions/${final_fleet_version}"
    local http_status
    http_status=$(curl -s -L -o /dev/null -w "%{http_code}" "$fleet_url")

    if [[ "$http_status" != "200" ]]; then
      echo "Warning: '${final_fleet_version}' not found in Fleet docs repo. Skipping update."
      final_fleet_version=""
    else
      echo "   Confirmed '${final_fleet_version}' exists in Fleet docs repo."
    fi
  fi

  local webhook_prime_mark
  local webhook_community_mark
  local new_current_prime_mark
  local new_current_community_mark
  [[ "${WEBHOOK_PRIME_AVAIL,,}" == "y" ]] && webhook_prime_mark="&#10003;" || webhook_prime_mark="&cross;"
  [[ "${WEBHOOK_COMMUNITY_AVAIL,,}" == "y" ]] && webhook_community_mark="&#10003;" || webhook_community_mark="&cross;"
  [[ "${NEW_CURRENT_PRIME_AVAIL,,}" == "y" ]] && new_current_prime_mark="&#10003;" || new_current_prime_mark="N/A"
  [[ "${NEW_CURRENT_COMMUNITY_AVAIL,,}" == "y" ]] && new_current_community_mark="&#10003;" || new_current_community_mark="N/A"

  # Define file paths
  local antora_file_versions="${DOCS_REPO_PATH}/versions/${minor_version_with_v}/antora.yml"
  local antora_file_community="${DOCS_REPO_PATH}/community-docs/${minor_version_with_v}/antora.yml"
  local antora_file_community_latest="${DOCS_REPO_PATH}/community-docs/latest/antora.yml"
  local antora_file_srfa="${DOCS_REPO_PATH}/versions/${minor_version_with_v}/antora-yml/antora-srfa.yml"

  # Define path to the modules directory where locales are stored
  local modules_path="${DOCS_REPO_PATH}/versions/${minor_version_with_v}/modules"
  # Initialize arrays to keep track of target files and available locales
  local all_files=()
  local locales=()

  # Iterate through all subdirectories in the modules folder to dynamically detect locales
  for locale_dir in "$modules_path"/*; do
    # Skip any item that is not a directory
    if [[ ! -d "$locale_dir" ]]; then continue; fi
    local locale
    # Extract the locale name (e.g., 'en', 'zh') and add it to the locales array
    locale=$(basename "$locale_dir")
    locales+=("$locale")

    # Append the file paths for the current locale to the all_files array for existence validation and revdate updates
    local base_path="${locale_dir}/pages"
    all_files+=(
      "${base_path}/release-notes.adoc"
      "${base_path}/security/rancher-webhook/rancher-webhook.adoc"
      "${base_path}/faq/deprecated-features.adoc"
    )

    if is_csp_adapter_supported "$minor_version_with_v"; then
      all_files+=(
        "${base_path}/installation-and-upgrade/hosted-kubernetes/cloud-marketplace/aws/install-adapter.adoc"
      )
    fi
  done

  for file in "${all_files[@]}"; do
    if [[ ! -f "$file" ]]; then
      echo "Error: File not found at '$file'. Please check DOCS_REPO_PATH and version number." >&2
      exit 1
    fi
  done

  echo "Starting release task automation for version ${VERSION}..."
  echo

  # Update revdate on all files
  for file in "${all_files[@]}"; do
    update_revdate "$file" "$iso_date"
  done

  # Update antora.yml files
  if [[ -n "$final_turtles_version" ]]; then
    if [[ -f "$antora_file_versions" ]]; then
      update_antora_attr "$antora_file_versions" "turtles-docs-version" "$final_turtles_version"
    fi
    if [[ -f "$antora_file_community" ]]; then
      update_antora_attr "$antora_file_community" "turtles-docs-version" "$final_turtles_version"
    fi
    if [[ -f "$antora_file_srfa" ]]; then
      update_antora_attr "$antora_file_srfa" "turtles-docs-version" "$final_turtles_version"
    fi
  fi

  if [[ -n "$final_fleet_version" ]]; then
    if [[ -f "$antora_file_versions" ]]; then
      update_antora_attr "$antora_file_versions" "fleet-docs-version" "$final_fleet_version"
    fi
    if [[ -f "$antora_file_community" ]]; then
      # Strip 'v' prefix for Fleet community docs
      local fleet_version_community="${final_fleet_version#v}"
      update_antora_attr "$antora_file_community" "fleet-docs-version" "$fleet_version_community"
    fi
    if [[ -f "$antora_file_srfa" ]]; then
      update_antora_attr "$antora_file_srfa" "fleet-docs-version" "$final_fleet_version"
    fi
  fi

  local current_patch_version="${VERSION#v}"
  local existing_community_patch=""
  if [[ -f "$antora_file_community" ]]; then
    existing_community_patch=$(awk '/^\s*current-patch-version:/ {print $2}' "$antora_file_community" | tr -d '[:space:]')
  fi

  if [[ "$NEW_CURRENT_PRIME_AVAIL" == "y" && "$NEW_CURRENT_COMMUNITY_AVAIL" == "n" ]]; then
    # Strip 'v' prefix
    if [[ -f "$antora_file_versions" ]]; then
      update_antora_attr "$antora_file_versions" "current-patch-version" "$current_patch_version"
    fi
    if [[ -f "$antora_file_srfa" ]]; then
      update_antora_attr "$antora_file_srfa" "current-patch-version" "$current_patch_version"
    fi
  else
    if [[ -f "$antora_file_versions" && -f "$antora_file_community" ]]; then
      update_antora_attr "$antora_file_versions" "current-patch-version" "$current_patch_version"
      update_antora_attr "$antora_file_community" "current-patch-version" "$current_patch_version"
    fi
    if [[ -f "$antora_file_srfa" ]]; then
      update_antora_attr "$antora_file_srfa" "current-patch-version" "$current_patch_version"
    fi
  fi

  # Update page-target-edit-version in community-docs/${minor_version_with_v}/antora.yml
  if [[ -f "$antora_file_community" ]]; then
    update_antora_attr "$antora_file_community" "page-target-edit-version" "\"${minor_version_with_v}\""
  fi

  # Determine latest non-prerelease minor version under community-docs/ and update community-docs/latest/antora.yml
  local comm_dirs=()
  for dir in "${DOCS_REPO_PATH}/community-docs"/v[0-9]*.[0-9]*; do
    if [[ -d "$dir" ]]; then
      comm_dirs+=("$(basename "$dir")")
    fi
  done

  if [[ ${#comm_dirs[@]} -gt 0 ]]; then
    local sorted_dirs
    sorted_dirs=$(printf '%s\n' "${comm_dirs[@]}" | sort -V -r)
    local latest_community_minor=""
    for v in $sorted_dirs; do
      local antora_f="${DOCS_REPO_PATH}/community-docs/${v}/antora.yml"
      if [[ -f "$antora_f" ]]; then
        # Check if version is pre-release: (Unreleased)
        if ! grep -q "^prerelease:\s*(Unreleased)" "$antora_f"; then
          latest_community_minor="$v"
          break
        fi
      fi
    done

    # Only synchronize community-docs/latest/antora.yml when the version:
    # 1. is available in Community
    # 2. belongs to the latest non-prerelease minor
    # 3. is greater than or equal to the existing patch version in that minor stream
    local is_latest_patch=false
    if [[ "${NEW_CURRENT_COMMUNITY_AVAIL,,}" == "y" ]] && [[ -n "$latest_community_minor" ]] && [[ "$minor_version_with_v" == "$latest_community_minor" ]]; then
      if [[ -z "$existing_community_patch" ]]; then
        is_latest_patch=true
      else
        local lowest_patch
        lowest_patch=$(printf '%s\n%s\n' "$current_patch_version" "$existing_community_patch" | sort -V | head -n1)
        if [[ "$lowest_patch" == "$existing_community_patch" ]]; then
          is_latest_patch=true
        fi
      fi
    fi

    if "$is_latest_patch" && [[ -f "$antora_file_community_latest" ]]; then
      echo "-> Synchronizing community-docs/latest to ${latest_community_minor} (${current_patch_version})..."
      update_antora_attr "$antora_file_community_latest" "page-target-edit-version" "\"${latest_community_minor}\""
      update_antora_attr "$antora_file_community_latest" "current-patch-version" "$current_patch_version"
    fi
  fi

  local adapter_row=""
  if is_csp_adapter_supported "$minor_version_with_v"; then
    adapter_row="| ${VERSION}"$'\n'"| v${ADAPTER_VERSION#v}"$'\n'
  fi

  local webhook_version_clean="${WEBHOOK_VERSION##*up}"
  webhook_version_clean="${webhook_version_clean%%-rc*}"
  local webhook_row
  webhook_row="| ${VERSION}"$'\n'"| v${webhook_version_clean}"$'\n'"| ${webhook_prime_mark}"$'\n'"| ${webhook_community_mark}"$'\n'

  local deprecated_row
  deprecated_row="| https://github.com/rancher/rancher/releases/tag/${VERSION}[${version_no_v}]"$'\n'"| ${iso_date}"$'\n'

  # Iterate through each detected locale to apply content updates
  for locale in "${locales[@]}"; do
    # Set the base pages path for the current locale
    local base_path="${modules_path}/${locale}/pages"

    # Update the specific AsciiDoc files for the current locale with the new version rows and notes
    update_release_notes "${base_path}/release-notes.adoc" "$VERSION" "$new_current_prime_mark" "$new_current_community_mark"
    if is_csp_adapter_supported "$minor_version_with_v"; then
      update_matrix "${base_path}/installation-and-upgrade/hosted-kubernetes/cloud-marketplace/aws/install-adapter.adoc" "\/\/ DO NOT EDIT THIS LINE, REQUIRED BY RELEASE SCRIPT\." "$adapter_row"
    fi
    update_matrix "${base_path}/security/rancher-webhook/rancher-webhook.adoc" "\/\/ DO NOT EDIT THIS LINE, REQUIRED BY RELEASE SCRIPT\." "$webhook_row"
    update_matrix "${base_path}/faq/deprecated-features.adoc" "\/\/ DO NOT EDIT THIS LINE, REQUIRED BY RELEASE SCRIPT\." "$deprecated_row"
  done

  echo "✅ All tasks completed."
}

# Run the main function with all provided arguments
main "$@"
