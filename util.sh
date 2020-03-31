#! /usr/bin/env bash

ROOT_DIR="$(dirname "$0")"

source "$ROOT_DIR"/logger.sh || exit 1

function is_env_set() {
	local var="$1"
	[ -n "${!var}" ]
}

function get_ds_tmp_dir() {
	local img_dir="$1"
	[ -n "$img_dir" ] && {
		echo "$img_dir"
		return 0
	}

	is_env_set "DS_TMP_DIR" && {
		echo "${DS_TMP_DIR}"
		return 0
	}
	is_env_set "DS_HOME" && {
		echo "$DS_HOME"/tmp
		return 0
	}

	echo "$HOME"/vms/tmp
}

function get_img_dir() {
	local img_dir="$1"
	[ -n "$img_dir" ] && {
		echo "$img_dir"
		return 0
	}

	is_env_set "DS_IMG_DIR" && {
		echo "${DS_IMG_DIR}"
		return 0
	}
	is_env_set "DS_HOME" && {
		echo "$DS_HOME"/imgs
		return 0
	}

	echo "$HOME"/imgs
}

function get_ram_dir() {
	local ram_dir="$1"

	[ -n "$ram_dir" ] && {
		echo "$ram_dir"
		return 0
	}

	is_env_set "DS_RAM_DIR" && {
		echo "${DS_IMG_DIR}"
		return 0
	}
	is_env_set "DS_HOME" && {
		echo "$DS_HOME"/ram
		return 0
	}

	echo "$HOME"/imgs/ram
}

function solution_to_clipborad() {
	local message="$1"
	[ -z "$message" ] && {
		error "Solution is empty. Nothing has been added to X11's clipboard" >&2
		return 0
	}

	which xclip >/dev/null 2>&1 && {
		xclip -sel clip <<< "$message" &> /dev/null &&
		info_purple "The command to solve the problem above added to X11's clipboard"
	}
}

function dir_exists() {
	local dir_name="$1"
	[ -d "$dir_name" ] || {
		error 'The directory "%s" does not exists, please create one:\n\tmkdir -p %s \033[0m' \
			"$dir_name" \
			"$dir_name"

		solution_to_clipborad "$(printf "mkdir -p %s" "$dir_name")"
		return 1
	}
}

function ensure_dirs() {
	for dir in "$@";
	do
		dir_exists "$dir" || return 1
		success 'The "%s" directory [FOUND]' "$dir"
	done
}

function calc_available_ram() {
	local percentage=$(("${1:-80}" / 10))
	[ "$percentage" -lt 10 ] || {
		error "Unable to allocate %d%% of RAM" "$((percentage * 10))"
		return 1
	}

	local total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
	[ -n "$total_mem" ] && {
		local available_mem=$((total_mem * percentage / 10))
		echo "$available_mem"K
	}
}

function check_dir_of_fs() {
	local dir="$1"
	local fs="${2:-tmpfs}"

	[ ! -d "$dir" ] && {
		error 'No directory "%s" found.' "$dir"
		solution_to_clipborad "$(printf "mkdir -p %s" "$dir")"
		return 1
	}

	df --type="$fs" "$dir" >/dev/null 2>&1 || {
		local available_mem=$(calc_available_ram)
		error 'The "%s" directory is not mounted into "%s". Please mount it:\n\tsudo mount -t %s -o rw,nodev,suid,size=%s %s %s\n' \
			"$dir" "$fs" "$fs" "$available_mem" "$fs" "$dir"

		solution_to_clipborad "$(echo sudo mount -t "$fs" -o rw,nodev,suid,size="$available_mem" "$fs" "$dir")"
		return 1
	}

	success 'The "%s" directory is mounted to "%s"' "$dir" "$fs"
}

function check_tools_installed() {
	printf "%s\n" which df rsync systemd-nspawn sudo grep awk curl sed tar | check_tool_installed
}

function check_tool_installed() {
	while read tool
	do
		type "$tool" >/dev/null 2>&1 || {
			error '%s [NOT FOUND]' "$tool"
			solution_to_clipborad "sudo pacman -S $tool"
			return 1
		}

		success '%s [FOUND]' "$(type "$tool")"
	done
}

function check_container_name() {
	local container="$1"
	[ -n "$container" ] || {
		error 'No container name specified. Usage:\n\t%s CONTAINER_NAME [OPTIONS]\n\n' "$0"
	}
}

function common_prechecks() {
	local container="$1"
	local img_dir="$2"
	local ram_dir="$3"

	check_tools_installed &&
		check_container_name "$container" &&
		ensure_dirs "$img_dir" "$ram_dir" &&
		check_dir_of_fs "$ram_dir"
}

function load_latest_release() {
	curl -s -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/neshkeev/devspace/releases/latest
}

function extract_assets_url() {
	sed -n '/"assets_url": /{s,.*"\(https:.*\)".*,\1,p;q}'
}

function load_assets() {
	read assets_url
	curl -s -H "Accept: application/vnd.github.v3+json" "$assets_url"
}

function extract_assets() {
	# either "name" comes before "browser_download_url" or the other way around
	sed -n '
		/"name":/{
			s,.*"name":.*"\([^"]\+\)".*,\1,;h;
			:o;n;
			/"browser_download_url": /!bo;
			s,.*"\(https:.*\)".*,\1,;
			H;g;s,\n, ,p;
		}
		/"browser_download_url":/{
			s,.*"browser_download_url":.*"\(https:.*\)".*,\1,;h;
			:w;n;
			/"name": /!bw;
			s,.*"\([^"]\+\)".*,\1,;
			G;s,\n, ,p;
		}
	'
}

function list_remote_containers() {
	load_latest_release | extract_assets_url | load_assets | extract_assets
}

function list_local_containers() {
	local img_dir=$(get_img_dir)

	dir_exists "$img_dir" || return 1

	find "$img_dir" -maxdepth 1 -type d | grep -v "^$img_dir$" | sed 's,.*/\([^/]\+\).*,\1,'
}
