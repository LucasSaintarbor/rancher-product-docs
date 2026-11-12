#!/bin/bash

set -e

# Displays script usage information
show_usage() {
    echo "Usage: $0 <new-release-version>"
    echo "Example: $0 v2.13.5"
    echo ""
    echo "This script automates creating the initial release notes draft for a new Rancher version."
    echo "It will base the new draft on the latest existing release notes for the same minor version, or the preceding minor version if needed."
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Ensure a version argument is provided
if [ -z "$1" ]; then
    show_usage
    exit 1
fi

NEW_VERSION=$1

# Validate the version format matches vX.Y.Z
if [[ ! "$NEW_VERSION" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "Error: Invalid version format. The format must be like 'v2.13.5'."
    exit 1
fi

# Extract the minor version (e.g., v2.13) from the input
MINOR_VERSION="v${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"

# Determine the repository root based on the script's location
REPO_ROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )

# Verify the versions directory exists in the repo root
VERSIONS_DIR="$REPO_ROOT/versions/$MINOR_VERSION"
if [ ! -d "$VERSIONS_DIR" ]; then
    echo "Error: Directory '$VERSIONS_DIR' does not exist."
    exit 1
fi

# Verify the release notes directory exists in the versions directory
RN_DIR="$VERSIONS_DIR/modules/en/pages/release-notes"
if [ ! -d "$RN_DIR" ]; then
    echo "Error: Release notes directory '$RN_DIR' does not exist."
    exit 1
fi

# Scan for the latest release version .adoc file in the current minor version
# Uses find and version sort (-V) to grab the highest versioned .adoc file
TEMPLATE_DIR="$RN_DIR"
LATEST_FILE=$(find "$RN_DIR" -maxdepth 1 -name "v*.adoc" -printf "%f\n" | sort -V | tail -n 1)

if [ -z "$LATEST_FILE" ]; then
    PREVIOUS_MINOR=$(find "$REPO_ROOT/versions" -mindepth 1 -maxdepth 1 -type d -name 'v[0-9]*' -printf "%f\n" | sort -V | awk -v target="$MINOR_VERSION" '
    $0 == target { print previous; exit }
    { previous = $0 }
    ')

    if [ -n "$PREVIOUS_MINOR" ]; then
        TEMPLATE_DIR="$REPO_ROOT/versions/$PREVIOUS_MINOR/modules/en/pages/release-notes"
        if [ -d "$TEMPLATE_DIR" ]; then
            LATEST_FILE=$(find "$TEMPLATE_DIR" -maxdepth 1 -name "v*.adoc" -printf "%f\n" | sort -V | tail -n 1)
        fi
    fi

    if [ -z "$LATEST_FILE" ]; then
        echo "Error: No existing release notes found in '$RN_DIR' or the preceding minor version to use as a template."
        exit 1
    fi
fi

# Extract the previous version string from the file name (e.g., v2.13.4)
PREV_VERSION="${LATEST_FILE%.adoc}"

if [ "$NEW_VERSION" == "$PREV_VERSION" ]; then
    echo "Error: The requested version $NEW_VERSION already matches the latest existing file."
    exit 1
fi

NEW_FILE="$RN_DIR/$NEW_VERSION.adoc"

echo "Using $LATEST_FILE as a template..."
cp "$TEMPLATE_DIR/$LATEST_FILE" "$NEW_FILE"

CURRENT_DATE=$(date +%Y-%m-%d)

echo "Updating attributes in $NEW_FILE..."

# Fetch latest K8s versions from data.json
DATA_URL="https://releases.rancher.com/kontainer-driver-metadata/release-${MINOR_VERSION}/data.json"
DATA_JSON=$(mktemp)
echo "Fetching KDM data from $DATA_URL..."
curl -sSfL "$DATA_URL" -o "$DATA_JSON" || echo "Warning: Failed to fetch $DATA_URL"

LATEST_K8S=""
if ! command -v jq &> /dev/null; then
    echo "Warning: 'jq' is not installed. Skipping automatic Kubernetes version extraction."
elif [ -s "$DATA_JSON" ]; then
    echo "Extracting latest Kubernetes versions from data.json for $NEW_VERSION..."
    K8S_VERSIONS=$(jq -r '.k3s.releases[] | select(.minChannelServerVersion != null and .maxChannelServerVersion != null) | "\(.version) \(.minChannelServerVersion) \(.maxChannelServerVersion)"' "$DATA_JSON" 2>/dev/null | awk -v target="$NEW_VERSION" '
    function ver_val(v) {
        sub(/^v/, "", v);
        sub(/-.*$/, "", v);
        split(v, a, ".");
        return (a[1]+0) * 1000000 + (a[2]+0) * 1000 + (a[3]+0);
    }
    BEGIN { tv = ver_val(target); }
    {
        minv = ver_val($2);
        maxv = ver_val($3);
        if (tv >= minv && tv <= maxv) {
            print $1;
        }
    }')
    if [ -n "$K8S_VERSIONS" ]; then
        CLEAN_VERSIONS=$(echo "$K8S_VERSIONS" | cut -d'+' -f1 | sort -V -r)
        SEEN_MINORS=""
        COUNT=0
        for v in $CLEAN_VERSIONS; do
            MINOR=$(echo "$v" | cut -d'.' -f1,2)
            if [[ ! "$SEEN_MINORS" =~ "$MINOR" ]]; then
                SEEN_MINORS="$SEEN_MINORS $MINOR"
                if [ $COUNT -eq 0 ]; then
                    LATEST_K8S="* $v (Default)"
                else
                    LATEST_K8S="$LATEST_K8S
* $v"
                fi
                COUNT=$((COUNT+1))
            fi
        done
    fi
fi
rm -f "$DATA_JSON"

# If the template was a .0 release, check if we need to add missing sections
ADD_PREV_ATTR=0
ADD_CHANGES_SEC=0
if [[ "$PREV_VERSION" == *.0 ]]; then
    if ! grep -q "^:previous-release-version:" "$NEW_FILE"; then
        ADD_PREV_ATTR=1
    fi
    if ! grep -q "^== Changes Since {previous-release-version}" "$NEW_FILE"; then
        ADD_CHANGES_SEC=1
    fi
fi

# Update only the first occurrences of the specified attributes using awk
awk -v date="$CURRENT_DATE" \
    -v new_ver="$NEW_VERSION" \
    -v minor_ver="$MINOR_VERSION" \
    -v prev_ver="$PREV_VERSION" \
    -v add_prev="$ADD_PREV_ATTR" \
    -v add_changes="$ADD_CHANGES_SEC" \
    -v k8s_list="$LATEST_K8S" '
BEGIN {
    # Initialize the list of top-level sections that must exist in the release notes
    sec_list[1] = "== Rancher General";
    sec_list[2] = "== Rancher App (Global UI)";
    sec_list[3] = "== Authentication";
    sec_list[4] = "== Cluster Provisioning";
    sec_list[5] = "== Rancher Webhook";
    sec_list[6] = "== K3s Provisioning";
    sec_list[7] = "== RKE2 Provisioning";
    sec_list[8] = "== Backup/Restore";
    sec_list[9] = "== Continuous Delivery (Fleet)";
    sec_list[10] = "== SUSE Virtualization (Harvester)";
}

# Converts a section name into a lowercased, underscore-separated slug
function get_slug(name,   slug) {
    slug = tolower(name);
    sub(/^==+[ \t]+/, "", slug);
    gsub(/[^a-z0-9]+/, "_", slug);
    sub(/_$/, "", slug);
    return slug;
}
# Generates an AsciiDoc anchor ID based on the given section name
function gen_id(name) {
    return "[#_" get_slug(name) "]";
}
# Appends the parent section slug to a subsection ID to ensure uniqueness
function postprocess_id(id, parent_sec) {
    sub(/\]$/, "_" get_slug(parent_sec) "]", id);
    return id;
}
# Checks the list of required sections and inserts any that were not found in the template
function insert_missing_sections() {
    if (missing_sections_done) return;
    for (i = 1; i <= 10; i++) {
        if (!seen_sec[sec_list[i]]) {
            print gen_id(sec_list[i]);
            print sec_list[i];
            print "";
            print postprocess_id("[#_features_and_enhancements]", sec_list[i]);
            print "=== Features and Enhancements";
            print "";
            print postprocess_id("[#_major_bug_fixes]", sec_list[i]);
            print "=== Major Bug Fixes";
            print "";
            print postprocess_id("[#_known_issues]", sec_list[i]);
            print "=== Known Issues";
            print "";
        }
    }
    missing_sections_done = 1;
}
# Prints any buffered AsciiDoc anchor ID and clears the buffer
function flush_id() {
    if (buffered_id != "") {
        print buffered_id;
        buffered_id = "";
    }
}

# Buffer AsciiDoc anchor IDs to associate them with the correct section later
/^\[#.*\]$/ {
    buffered_id = $0;
    next;
}
# Skip lines within the Kubernetes versions block until a new section starts
skip_k8s {
    if (/^==+ /) {
        skip_k8s = 0;
    } else {
        buffered_id = "";
        next;
    }
}
# Track top-level sections (both commented and uncommented) to know what is already present
/^\/\/== / || /^== / {
    sec_name = $0;
    sub(/^\/\//, "", sec_name);
    sub(/[ \t]+$/, "", sec_name);
    seen_sec[sec_name] = 1;
}
# Update the revision date attribute
/^:revdate:/ && !revdate_done { 
    flush_id();
    print ":revdate: " date; 
    revdate_done=1; 
    next 
}
# Update the release version attribute
/^:release-version:/ && !release_done { 
    flush_id();
    print ":release-version: " new_ver; 
    release_done=1; 
    next 
}
# Update the component version and optionally insert the previous release version attribute
/^:rn-component-version:/ && !component_done { 
    flush_id();
    print ":rn-component-version: " minor_ver; 
    if (add_prev == 1) {
        print ":previous-release-version: " prev_ver;
    }
    component_done=1; 
    next 
}
# Update the previous release version attribute if it already exists
/^:previous-release-version:/ && !prev_done { 
    flush_id();
    print ":previous-release-version: " prev_ver; 
    prev_done=1; 
    next 
}
# Insert missing sections before the "Changes Since" section
/^== Changes Since / {
    insert_missing_sections();
    flush_id();
    print;
    next;
}
# Insert missing sections before the "Install/Upgrade Notes" section, and optionally add the "Changes Since" section
/^== Install\/Upgrade Notes/ && !changes_done {
    insert_missing_sections();
    if (add_changes == 1) {
        print "[#_changes_since_previous_release_version]";
        print "== Changes Since {previous-release-version}";
        print "";
        print "See the full list of https://github.com/rancher/rancher/compare/{previous-release-version}%E2%80%A6{release-version}[changes].";
        print "";
    }
    changes_done=1;
    flush_id();
    print;
    next
}
# Replace the contents of the Kubernetes versions block with the freshly fetched list
/^=== Kubernetes Versions for RKE2\/K3s/ {
    flush_id();
    print
    if (k8s_list != "") {
        print ""
        print k8s_list
        print ""
        skip_k8s = 1
    }
    next
}
# Pass through all other lines
{ 
    flush_id();
    print 
}
' "$NEW_FILE" > "${NEW_FILE}.tmp" && mv "${NEW_FILE}.tmp" "$NEW_FILE"

echo "Successfully generated initial release notes draft: $NEW_FILE"

# Update the English navigation file if needed
NAV_FILE="$VERSIONS_DIR/modules/en/nav.adoc"
if [ -f "$NAV_FILE" ]; then
    if grep -Fq "** xref:release-notes/${NEW_VERSION}.adoc[]" "$NAV_FILE"; then
        echo "Navigation entry already exists in $NAV_FILE. Skipping."
    else
        echo "Updating navigation file $NAV_FILE..."
        awk -v new_entry="** xref:release-notes/${NEW_VERSION}.adoc[]" '
        !inserted && /^\*\* xref:release-notes\/v.*\.adoc\[\]/ {
            print new_entry
            inserted = 1
        }
        /^\* xref:release-notes\.adoc\[.*\]/ {
            print
            in_rn = 1
            next
        }
        !inserted && in_rn && /^\* / {
            print new_entry
            inserted = 1
            in_rn = 0
        }
        { print }
        END {
            if (in_rn && !inserted) {
                print new_entry
            }
        }
        ' "$NAV_FILE" > "${NAV_FILE}.tmp" && mv "${NAV_FILE}.tmp" "$NAV_FILE"
    fi
else
    echo "Warning: Navigation file $NAV_FILE not found. Skipping nav update."
fi

# Iterate over other locales and update their navigation files as well
for LOCALE_DIR in "$VERSIONS_DIR/modules/"*; do
    if [ ! -d "$LOCALE_DIR" ]; then continue; fi
    LOCALE=$(basename "$LOCALE_DIR")
    if [ "$LOCALE" == "en" ]; then continue; fi

    LOCALE_NAV_FILE="$LOCALE_DIR/nav.adoc"
    if [ -f "$LOCALE_NAV_FILE" ]; then
        if grep -Fq "** xref:release-notes/${NEW_VERSION}.adoc[]" "$LOCALE_NAV_FILE"; then
            echo "Navigation entry already exists in $LOCALE_NAV_FILE. Skipping."
        else
            echo "Updating navigation file $LOCALE_NAV_FILE..."
            awk -v new_entry="** xref:release-notes/${NEW_VERSION}.adoc[]" '
            !inserted && /^\*\* xref:release-notes\/v.*\.adoc\[\]/ {
                print new_entry
                inserted = 1
            }
            /^\* xref:release-notes\.adoc\[.*\]/ {
                print
                in_rn = 1
                next
            }
            !inserted && in_rn && /^\* / {
                print new_entry
                inserted = 1
                in_rn = 0
            }
            { print }
            END {
                if (in_rn && !inserted) {
                    print new_entry
                }
            }
            ' "$LOCALE_NAV_FILE" > "${LOCALE_NAV_FILE}.tmp" && mv "${LOCALE_NAV_FILE}.tmp" "$LOCALE_NAV_FILE"
        fi
    else
        echo "Warning: Navigation file $LOCALE_NAV_FILE not found. Skipping nav update for locale $LOCALE."
    fi
done
