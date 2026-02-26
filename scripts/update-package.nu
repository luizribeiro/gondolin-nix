#!/usr/bin/env nu

# Update gondolin package metadata and keep gondolin-guest-bins in lockstep.
#
# Usage:
#   nu scripts/update-package.nu gondolin
#   nu scripts/update-package.nu --check-lockstep
#   nu scripts/update-package.nu --refresh-hashes --system <system> [--write-hash-map <file>]
#   nu scripts/update-package.nu --apply-hash-map <file>

def parse_version [file: string] {
    (
        open $file
        | lines
        | where $it =~ 'version = '
        | first
        | str replace 'version = "' ''
        | str replace '";' ''
        | str trim
    )
}

def check_lockstep [] {
    let gondolin_version = parse_version "packages/gondolin/default.nix"
    let guest_bins_version = parse_version "packages/gondolin-guest-bins/default.nix"

    if $gondolin_version != $guest_bins_version {
        print $"Error: gondolin lockstep mismatch: gondolin=($gondolin_version), gondolin-guest-bins=($guest_bins_version)"
        return false
    }

    print $"✓ gondolin lockstep OK version=($gondolin_version)"
    true
}

def sync_guest_bins [version: string, hash_override?: string]: nothing -> bool {
    let package_file = "packages/gondolin-guest-bins/default.nix"

    let sri_hash = if ($hash_override | is-not-empty) {
        $hash_override
    } else {
        let tarball_url = $"https://github.com/earendil-works/gondolin/archive/refs/tags/v($version).tar.gz"
        print $"Fetching hash for ($tarball_url)..."

        let hash_output = (nix-prefetch-url --unpack $tarball_url | complete)
        if $hash_output.exit_code != 0 {
            print $"Error fetching hash: ($hash_output.stderr)"
            return false
        }

        let nix_hash = $hash_output.stdout | str trim
        (nix hash convert --hash-algo sha256 $nix_hash | complete | get stdout | str trim)
    }

    let content = open $package_file
    let updated = (
        $content
        | str replace -r 'version = "[^"]*"' $'version = "($version)"'
        | str replace -r '(?s)(src = fetchFromGitHub \{.*?hash = )"sha256-[^"]*"' $'$1"($sri_hash)"'
    )

    $updated | save -f $package_file
    print $"✓ Synchronized gondolin-guest-bins to version ($version)"
    true
}

def refresh_hashes [system: string]: nothing -> bool {
    let package_file = "packages/gondolin/default.nix"
    let fake_hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

    let content = open $package_file
    if not ($content | str contains $'"($system)" = "') {
        print $"Skipping refresh: no outputHash entry for ($system)"
        return true
    }

    let updated = (
        $content
        | str replace -r $'"($system)" = "sha256-[^"]*"' $'"($system)" = "($fake_hash)"'
    )
    $updated | save -f $package_file

    print $"Building gondolin to compute outputHash for ($system)..."
    let build_result = (nix build .#gondolin --system $system --no-link | complete)
    let got_lines = ($build_result.stderr | lines | where $it =~ "got:")

    if ($got_lines | is-empty) {
        print "Error: Could not extract outputHash"
        print $build_result.stderr
        return false
    }

    let fod_hash = (
        $got_lines
        | first
        | str trim
        | split row "got:"
        | get 1
        | str trim
    )

    let content2 = open $package_file
    let updated2 = (
        $content2
        | str replace $'"($system)" = "($fake_hash)"' $'"($system)" = "($fod_hash)"'
    )
    $updated2 | save -f $package_file

    print $"✓ gondolin outputHash for ($system): ($fod_hash)"
    true
}

def build_hash_map [system: string] {
    let content = open "packages/gondolin/default.nix"
    let line = (
        $content
        | lines
        | where ($it | str contains $'"($system)" = "')
        | first
    )

    if ($line | is-empty) {
        {}
    } else {
        let hash = ($line | split row '"' | get 3)
        { gondolin: { $system: $hash } }
    }
}

def apply_hash_map [hash_map_file: string]: nothing -> bool {
    let hash_map = open $hash_map_file
    if not (($hash_map | columns) | any {|c| $c == "gondolin" }) {
        return true
    }

    let package_file = "packages/gondolin/default.nix"
    mut content = open $package_file

    for system in ($hash_map | get gondolin | columns) {
        let hash = ($hash_map | get gondolin | get $system)
        $content = ($content | str replace -r $'"($system)" = "sha256-[^"]*"' $'"($system)" = "($hash)"')
    }

    $content | save -f $package_file
    true
}

def update_gondolin [version: string, system: string]: nothing -> bool {
    let package_file = "packages/gondolin/default.nix"
    let content = open $package_file
    let fake_hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

    let tarball_url = $"https://registry.npmjs.org/@earendil-works/gondolin/-/gondolin-($version).tgz"
    print $"Fetching hash for ($tarball_url)..."

    let hash_output = (nix-prefetch-url $tarball_url | complete)
    if $hash_output.exit_code != 0 {
        print $"Error fetching hash: ($hash_output.stderr)"
        return false
    }

    let nix_hash = $hash_output.stdout | str trim
    let sri_hash = (nix hash convert --hash-algo sha256 $nix_hash | complete | get stdout | str trim)

    let updated = (
        $content
        | str replace -r 'version = "[^"]*"' $'version = "($version)"'
        | str replace -r '(?s)(src = fetchurl \{.*?hash = )"sha256-[^"]*"' $'$1"($sri_hash)"'
    )

    let updated2 = if ($updated | str contains $'"($system)" = "') {
        $updated | str replace -r $'"($system)" = "sha256-[^"]*"' $'"($system)" = "($fake_hash)"'
    } else {
        $updated
    }

    $updated2 | save -f $package_file

    if not ($updated2 | str contains $'"($system)" = "') {
        print $"Skipping outputHash refresh: no outputHash entry for ($system)"
        return true
    }

    print $"Building gondolin to compute outputHash for ($system)..."
    let build_result = (nix build .#gondolin --no-link | complete)
    let got_lines = ($build_result.stderr | lines | where $it =~ "got:")

    if ($got_lines | is-empty) {
        print "Error: Could not extract outputHash"
        print $build_result.stderr
        return false
    }

    let fod_hash = (
        $got_lines
        | first
        | str trim
        | split row "got:"
        | get 1
        | str trim
    )

    let content3 = open $package_file
    let updated3 = (
        $content3
        | str replace $'"($system)" = "($fake_hash)"' $'"($system)" = "($fod_hash)"'
    )
    $updated3 | save -f $package_file

    true
}

def main [package?: string, --check-lockstep, --refresh-hashes, --system: string, --write-hash-map: string, --apply-hash-map: string] {
    if $check_lockstep {
        if (check_lockstep) {
            print "updated=false"
            return
        }
        exit 1
    }

    if ($apply_hash_map | is-not-empty) {
        if not (apply_hash_map $apply_hash_map) {
            print "updated=false"
            exit 1
        }
        print "updated=true"
        return
    }

    if $refresh_hashes {
        let target_system = if ($system | is-empty) {
            nix eval --impure --expr builtins.currentSystem --raw | complete | get stdout | str trim
        } else {
            $system
        }

        if not (refresh_hashes $target_system) {
            print "updated=false"
            exit 1
        }

        if ($write_hash_map | is-not-empty) {
            let hash_map = (build_hash_map $target_system)
            $hash_map | to json | save -f $write_hash_map
            print $"wrote_hash_map=($write_hash_map)"
        }

        print "updated=true"
        print $"system=($target_system)"
        return
    }

    if ($package | is-empty) {
        print "Error: missing package argument"
        print "Usage:"
        print "  nu scripts/update-package.nu gondolin"
        print "  nu scripts/update-package.nu --check-lockstep"
        print "  nu scripts/update-package.nu --refresh-hashes --system <system> [--write-hash-map <file>]"
        print "  nu scripts/update-package.nu --apply-hash-map <file>"
        exit 1
    }

    if $package != "gondolin" {
        print $"Error: unknown package '($package)' (valid: gondolin)"
        exit 1
    }

    let current_version = parse_version "packages/gondolin/default.nix"
    let latest_version = (http get "https://registry.npmjs.org/@earendil-works/gondolin" | get dist-tags.latest)
    let current_system = (nix eval --impure --expr builtins.currentSystem --raw | complete | get stdout | str trim)

    print $"Current: ($current_version)"
    print $"Latest:  ($latest_version)"

    if $current_version == $latest_version {
        if not (check_lockstep) {
            print "↻ Synchronizing gondolin-guest-bins with current gondolin version"
            if not (sync_guest_bins $current_version) {
                print "updated=false"
                exit 1
            }
            print "updated=true"
            print $"current=($current_version)"
            print $"latest=($latest_version)"
            return
        }

        print "updated=false"
        print $"current=($current_version)"
        print $"latest=($latest_version)"
        return
    }

    if not (update_gondolin $latest_version $current_system) {
        print "updated=false"
        exit 1
    }

    if not (sync_guest_bins $latest_version) {
        print "updated=false"
        exit 1
    }

    print "updated=true"
    print $"current=($current_version)"
    print $"latest=($latest_version)"
}
