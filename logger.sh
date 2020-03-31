
function info() {
	local msg="$1"
	shift
	printf "[INFO]: $msg\n" "$@"
}

function info_blue() {
	local msg="$1"
	shift
	printf "\033[34m[INFO]: $msg\n\033[0m" "$@"
}

function info_purple() {
	local msg="$1"
	shift
	printf "\033[35m[INFO]: $msg\n\033[0m" "$@"
}

function info_aqua() {
	local msg="$1"
	shift
	printf "\033[36m[INFO]: $msg\n\033[0m" "$@"
}

function info_gray() {
	local msg="$1"
	shift
	printf "\033[37m[INFO]: $msg\n\033[0m" "$@"
}

function success() {
	local msg="$1"
	shift
	printf "\033[32m[INFO]: $msg\n\033[0m" "$@"
}

function success_stdin() {
	while read msg; do
		printf "\033[32m[INFO]: $msg\n\033[0m" "$@"
	done
}

function warn() {
	local msg="$1"
	shift
	printf "\033[33m[WARNING]: $msg\n\033[0m" "$@" >&2
	return 1
}

function error() {
	local msg="$1"
	shift
	printf "\033[31m[ERROR]: $msg\n\033[0m" "$@" >&2
	return 1
}
