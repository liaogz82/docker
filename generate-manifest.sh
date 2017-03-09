#!/bin/bash

self="$(basename "$BASH_SOURCE")"

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		fileCommit Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						print $i
					}
				}
			')
	)
}

# determine actual composer version based on COMPOSER_VERSION value
extractVersion() {
    git show "$1":"$2/Dockerfile" | awk '$1 == "ENV" && $2 == "COMPOSER_VERSION" { print $3; exit }'
}

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

directories=( */ )
directories=( "${directories[@]%/}" )

# sort directories descending
IFS=$'\n'; directories=( $(echo "${directories[*]}" | sort -rV) ); unset IFS

declare -A aliases=(
	[1.4]='1 latest'
)

# manifest header
cat <<-EOH
# this file was generated using https://github.com/composer/docker/blob/$(fileCommit "$self")/$self

Maintainers: Composer (@composer), Rob Bast (@alcohol)
GitRepo: https://github.com/composer/docker.git
EOH

# image metadata for each directory found
for directory in "${directories[@]}"; do
    commit="$(dirCommit "$directory")"
    version="$(extractVersion "$commit" "$directory")"
    tags=($version $directory ${aliases[$directory]:-})

    cat <<-EOE

		Tags: $(join ', ' "${tags[@]}")
		GitCommit: $commit
		Directory: $directory
	EOE
done
