RELEASE_FILENAME=webwork-open-problem-library-METADATA.tar.gz
GITHUB_USERNAME=heiderich
GITHUB_REPO=webwork-open-problem-library
JSON_FILENAME=latest_release.json
RELEASE_TAG=latest_release.tag

${JSON_FILENAME}:
	@echo "Download a JSON containing information on the latest release"
	curl -s https://api.github.com/repos/${GITHUB_USERNAME}/${GITHUB_REPO}/releases/latest > ${JSON_FILENAME}

${RELEASE_TAG}: ${JSON_FILENAME}
	jq -r '.tag_name' ${JSON_FILENAME} > ${RELEASE_TAG}

${RELEASE_FILENAME}: ${JSON_FILENAME}
	curl -L `jq -r '[.assets | .[] | select(.name == "${RELEASE_FILENAME}" ) | .browser_download_url][0]' ${JSON_FILENAME}` -o ${RELEASE_FILENAME}

extract: ${RELEASE_FILENAME}
	tar xfz ${RELEASE_FILENAME}

clean:
	rm -f ${RELEASE_FILENAME} ${RELEASE_TAG} ${JSON_FILENAME}
