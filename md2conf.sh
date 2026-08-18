#!/usr/bin/env sh

# Wrap kovetskiy/mark to upload md files based on path
# You need to specify all args using env var because this script only accept one path as arg
# Example:
# MARK_SPACE=DATA MARK_PARENTS=Data/ChatBot md2conf.sh docs

set -e

SRC=$(realpath "${1}")
pwd_basename=$(basename "${PWD}")
_MARK_PARENTS="${MARK_PARENTS}"

find "${SRC}" -name "*.md" -type f | while IFS= read -r file; do
    # For project located in /path/to/project, docs/deep/index.md with SRC=docs

    # dir_path will be "/path/to/project/docs/deep"
    dir_path=$(dirname "${file}")

    # relative_to_src_dir_path will be "deep"
    # this is used to determine Confluence parents
    relative_to_src_dir_path=$(echo "${dir_path}" | sed "s|^${SRC}||")

    # relative_to_project_path will be "docs/deep/index.md"
    # this is used to determine URL of the file in GitHub
    relative_to_project_path=$(echo "${file}" | sed "s|^${PWD}||")

    MARK_PARENTS="${_MARK_PARENTS}${relative_to_src_dir_path}"

    echo "Uploading ${file} to ${MARK_PARENTS}"

    heading_content="###### Built from [${pwd_basename}${relative_to_project_path}](${PROJECT_PREFIX_URL}${relative_to_project_path})"

    # Special handling for README.md files
    if [ "$(basename "${file}")" = "README.md" ]; then
        # Get the directory name for the H1 title
        h1_title=$(basename "${MARK_PARENTS}")

        # Remove the last segment from MARK_PARENTS to get the new parent
        MARK_PARENTS=$(echo "${MARK_PARENTS}" | sed 's|/[^/]*$||')

        # Replace the H1 title with the directory name
        awk "/^# / && !found { print \"# ${h1_title}\"; found=1; next } { print }" "${file}" > "${file}.tmp"
        mv "${file}.tmp" "${file}"
    fi

    # insert heading after first H1
    awk "/^# / && !found { print; print \"${heading_content}\"; found=1; next } { print }" "${file}" > "${file}.tmp"
    mv "${file}.tmp" "${file}"

    mark --files "${file}"
done
