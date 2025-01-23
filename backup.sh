#!/usr/bin/env bash
# set -ex

## check if something is installed
isInstalled(){
    if [[ "$(command -v ${1})" == "" ]]; then
        echo "${1} not found, please install"
        exit 0
    fi
}
isInstalled sops
isInstalled meshtastic
isInstalled perl

## make sure there's a .sops.yaml cfg
if [[ ! -f ".sops.yaml" ]]; then
    echo ".sops.yaml not found - please reread Installation instructions"
    exit 0
fi

## dump entire cfg
meshtastic --export-config > /tmp/config.yaml 2>/dev/null

## verify we have a meshtastic config.yaml and not some stderr dump
if [[ "$(grep -c '# start of Meshtastic configure yaml' /tmp/config.yaml)" == 0 ]]; then
    echo "Exported config invalid, attempting further diagnosis..."
    ## check dev path depending on OS and use exit code via $? as verification
    arch="$(uname -s)"
    if [[ "${arch}" == "Darwin" ]]; then
        exitCode="$(ls /dev/cu.usbmodem* 2>/dev/null; echo $?)"
    elif [[ "${arch}" == "Linux" ]]; then
        exitCode="$(ls /dev/cu.ttyACM* 2>/dev/null; echo $?)"
    else
        echo "Detected OS not supported"
        exit 0
    fi
    if [[ "${exitCode}" -gt "0" ]]; then
        echo "Radio not found, retry with a different usb port / cable?"
        exit 0
    fi
fi

## extract owner_short for filename use, strip any quotes
owner_short="$(grep owner_short /tmp/config.yaml | awk '{print $2}' | tr -d \")"

## detect if owner_short is emoji to handle shenanigans
# isEmoji="$(grep -c 'owner_short: \"\\U000' /tmp/config.yaml)"
# if [[ ! "${isEmojio}" == 0 ]]; then
if [[ ! "$(grep -c 'owner_short: \"\\U000' /tmp/config.yaml)" == 0 ]]; then
    ## perl magic to rewrite the emoji's hex' as an emoji
    owner_short="$(perl -CO -plE 's/\\u(\p{Hex}+)/chr(hex($1))/xieg' <<< ${owner_short})"
fi

## confirm overwriting existing config
if [[ -f "${owner_short}_config.yaml" ]]; then
    read -n 1 -p "file exists, ok to overwrite? [y/n] " overwriteConfirm
    echo "" # read doesn't create newline
    case "${overwriteConfirm}" in
        y|Y)
            echo "overwriting ${owner_short}_config.yaml and proceeding..."
            ;;
        n|N)
            echo "renaming ${owner_short}_config.yaml and proceeding..."
            mv "${owner_short}_config.yaml" "${owner_short}_config-$(date +%Y-%m-%d_%H-%M-%S).yaml"
            ;;
        *)
            echo "$overwriteConfirm key not found - retry when you find either the y or n key"
            exit 0
            ;;
    esac
fi

## ensure owner_short is double-quoted so sops doesn't mangle it, emoji owner_short should already be quoted so nothing to do
if [[ $(grep -c1 'owner_short: "' /tmp/config.yaml) -eq 0 ]]; then
    ## avoid sed (mac) / gnused (linux) shenanigans with -i
    sed 's/owner_short: \(.*\)/owner_short: "\1"/' /tmp/config.yaml > "${owner_short}_config.yaml"
    rm -f /tmp/config.yaml
else
    mv /tmp/config.yaml "${owner_short}_config.yaml"
fi

## encrypt inplace (encrypted_regex values from .sops.yaml) ~ channel_url bluetooth.fixedPin security.privateKey mqtt.username/passwd
sops -e -i "${owner_short}_config.yaml"

## verify sops encryption
if [[ "$(filestatus ${owner_short}_config.yaml | sed 's/{"encrypted":\(.*\)}/\1/')" == "false" ]]; then
    echo "${owner_short}_config.yaml encryption not detected, attempting to re-encrypt and proceed..."
    sops -e -i "${owner_short}_config.yaml"
fi

## visually verify config
cat "${owner_short}_config.yaml"

## print out completion message
echo "=============================================="
## red text, bold
echo -e 'Radio backup complete. \033[31m\033[1mVerify this is correct!\033[0m'
echo "Rerun if wrong values! It's an inexactscience."
echo "=============================================="
