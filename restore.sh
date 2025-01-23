#!/usr/bin/env bash
set -e # x

## check if sops is installed
if [[ "$(command -v sops)" == "" ]]; then
    echo "sops not found, please install"
    exit 0
fi
## check if meshtastic is installed
if [[ "$(command -v meshtastic)" == "" ]]; then
    echo "meshtastic not found, please install"
    exit 0
fi

## no argument passed so display correct usage
if [[ -z "${1}" ]]; then
    echo "you didn't pass a config.yaml file name"
    echo "usage: ./restore.sh PRK1_config.yaml"
    exit 0
fi

## $1 is used inside functions so rename passed arg to new var
file="${1}"

## make sure config file exists
if [[ ! -f "${file}" ]]; then
    echo "file ${file} not found, check name and retry"
    echo "usage: ./restore.sh PRK1_config.yaml"
    exit 0
fi

## crudely verify sops encryption
if [[ "$(grep -c '^sops:$' "${file}"|bc)" == 0 ]]; then
    echo "${file} encryption not detected, attempting to re-encrypt and proceed..."
    sops -e -i ${file}
fi

## decrypt inplace config file
sops -d -i "${file}"

## apply config
meshtastic --config "${file}"

## reecrypt inplace config file
sops -e -i "${file}"

## double-check device's config
meshtastic --export-config

## print out completion message
echo "=============================================="
## red text, bold
echo -e 'Radio config restored. \033[31m\033[1mVerify this is correct!\033[0m'
echo "Rerun if wrong values! It's an inexactscience."
echo "=============================================="
