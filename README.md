my personal [meshtastic](https://meshtastic.org/) radio node configurations backups / personal fork of https://github.com/porkcube/meshtastic-configs

<hr />

# Meshtastic Configs

A fancy pants (read: convoluted/gitopsy) semi-automated way to safely and securely manage [meshtastic](https://meshtastic.org/) node `config.yaml` file(s) with `git` +
[`sops`](https://github.com/getsops/sops) for macOS and Linux - Feedback/PRs welcome!

# This works most reliably on a fresh, fully erased node.
#### Trying to run `restore.sh` on an already configured node is not guaranteed to fully work, and likely require multiple runs before configuration is completely applied, if it even fully applies.
Nobody is perfect and [any changed configuration value could not "stick" for any number of reasons](https://github.com/meshtastic/firmware/issues/5640), including [`LFS` corruption](https://github.com/meshtastic/firmware/issues/5839) from repeatedly trying to change the config (happened to me) hence the recommendation to use a fully erased node for best results.


#### That said, it works well for my own needs with that caveat, which is why I slapped it together.
It deals with basically every mistake I could make/edge case I encountered, and the `bash` is ~~extraneously~~ helpfully commented.

<hr />
<p align="center">nothing guaranteed, implied or insured - use at your own risk - verify encryption <b>BEFORE git push</b> - ymmv</p>
<hr />


- requirements:
  - [sops](https://github.com/getsops/sops) + [keypair from any/all of the following](https://github.com/getsops/sops?tab=readme-ov-file#using-sops-yaml-conf-to-select-kms-pgp-and-age-for-new-files):
    - age / pgp / gpg
    - aws / gcp kms
    - azure key vault / hashicorp vault
    - etc...
  - [meshtastic python cli](https://meshtastic.org/docs/software/python/cli/installation/?install-python-cli=macos):
    - `python3 -m venv ~/meshtastic-venv`
    - `source ~/meshtastic-venv/bin/activate`
    - `pip3 install --upgrade meshtastic`
  - a fork of this repo:
    - click `Fork` up in the top right, you then will save your own configs in your own copy of this repo, while still being able to cleanly pull in upstream changes to the scripts.


# Installation:
- macOS
  - `brew install sops`

- Linux (ok, only `debian` actually confirmed)
  - [sops releases and install directions](https://github.com/getsops/sops/releases)

~~Super~~ Some-what simple:
- clone your forked repo and change directory to it:
```
git clone https://github.com/(yourgithubusername)/meshtastic-configs
cd meshtastic-configs
```
- configure `sops` [with your desired encryption scheme](https://github.com/getsops/sops?tab=readme-ov-file#usage)
  - example using `age`:
    - macOS:
    ```
    brew install age
    mkdir -p $HOME/Library/Application\ Support/sops/age/
    age-keygen -o $HOME/Library/Application\ Support/sops/age/keys.txt
    ```
    - Linux (debian based):
    ```
    sudo apt install -y age
    mkdir -p $HOME/.config/sops/age/
    age-keygen -o $HOME/.config/sops/age/keys.txt
    ```
  - If successful it should return something like:
    - `Public key: age1dr0vunxfjwqgh9shx4cd2nyq0rcufnzds5g6au8nuw65ul9595useed9uj`
- Create a `.sops.yaml` `sops` config at the root of your forked repo that will default to using the newly created private key for cryptography, and
set it up to encrypt only the sensitive fields defined by `encrypted_regex:`.
```
creation_rules:
    - path_regex: .*yaml$
      encrypted_regex: channel_url|fixedPin|privateKey|password|username
      age: >-
        age1dr0vunxfjwqgh9shx4cd2nyq0rcufnzds5g6au8nuw65ul9595useed9uj
```

<p align="center">Now attach your node over USB and you're ready to begin!</p>

# Usage

### backup:

`./backup.sh`

This will create a `sops` encrypted file named `(owner_short)_config.yaml` (e.g. `PRK1_config.yaml`).
The `owner_short` name will be extracted from the existing config (emojis should work, they do for me) and explicitly double-quoted as `sops` may misinterpret certain ambiguous strings (e.g. `18e7`, edge case which so happened to be the node used while developing most of this).
The resulting file can be considered safe to commit/share publicly as only the "sensitive" information has been encrypted with the private key.
It will also add a comment at the end of the yaml with the device's current `firmware_version` and `device_state`.

The following "sensitive" values will be obfuscated if present (i.e. the `encrypted_regex` in `.sops.yaml`):
- `channel_url`
- `bluetooth.fixedPin`
- `security.privateKey`
- `module_config.mqtt.password`
- `module_config.mqtt.username`


### restore:

`./restore.sh (owner_short)_config.yaml`
<br />e.g. `./restore.sh PRK1_config.yaml`

Running `restore.sh` will decrypt and restore a node's configuration from a `sops` encrypted yaml.
You will need to pass the name of the `(owner_short)_config.yaml` file to use and it will warn if missing.
The node will automatically reboot at the end of this process.


### editing:

`sops edit (owner_short)_config.yaml`
<br />e.g. `sops edit PRK1_config.yaml`

`sops` will use your `$EDITOR` env if defined, otherwise default to `vi` (`esc`+`:q!`+`Enter` to exit out if you quickly ran the command without reading ahead).
You can also run `sops -d -i (owner_short)_config.yaml` to decrypt the file, open it your preferred cli or gui editor and have at, then run
`sops -e -i (owner_short)_config.yaml` once completed to ensure it's encrypted before committing with `git`.

# Extending

If you want to add or remove any key(s) from being encrypted, such as the `adminKey` array (because you're more paranoid than I) simple add them to the `encrypted_regex` in `.sops.yaml`:
- before: `encrypted_regex: channel_url|fixedPin|privateKey|password|username`
- after : `encrypted_regex: channel_url|fixedPin|adminKey|privateKey|password|username`

And then run : `sops -d -i file.yaml && sops -e -i file.yaml` to decrypt then reencrypt the file with the updated keys.
