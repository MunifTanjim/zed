# zed

ZSH Plugin Manager. Yes, yet another one.

## Installation

```sh
declare -A ZED
ZED[CACHE_DIR]="${HOME}/.cache/zsh/.zed"
ZED[DATA_DIR]="${HOME}/.local/share/zsh/.zed"

if ! test -d "${ZED[DATA_DIR]}/self"; then
  git clone --depth 1 https://github.com/MunifTanjim/zed.git "${ZED[DATA_DIR]}/self"
fi

source "${ZED[DATA_DIR]}/self/zed.zsh"
```

## Usage

You should load the plugins you want after running `zed init` and before running `zed done`.

**Initialization**:

```sh
zed init
```

**Normal Plugin**:

```sh
zed load github.com/momo-lab/auto-expand-alias

zed load github.com/trapd00r/LS_COLORS \
  pick:'lscolors.sh' \
  onpull:'dircolors -b LS_COLORS > lscolors.sh' \
  onload:'zstyle ":completion:*" list-colors "${(s.:.)LS_COLORS}"'

zed load github.com/zpm-zsh/colorize
zed load github.com/zpm-zsh/ls

zed load github.com/zsh-users/zsh-completions
zed load github.com/zsh-users/zsh-autosuggestions
zed load github.com/zsh-users/zsh-syntax-highlighting
```

**Generated Script**:

```sh
if (( ${+commands[zoxide]} )); then
  zed load github.com/MunifTanjim/null name:'zoxide' \
    onpull:'zoxide init zsh > zoxide.plugin.zsh'
fi

if (( ${+commands[starship]} )); then
  zed load github.com/MunifTanjim/null name:'starship' \
    onpull:'starship init zsh --print-full-init > starship.plugin.zsh'
fi
```

**Local Script**:

```
zed load "${HOME}/.helpers.sh"
```

**[Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) Plugin**:

```sh
zed load github.com/ohmyzsh/ohmyzsh dir:'plugins/macos'
```

**Finalization**:

```sh
zed done
```

### Commands

The main function is named `zed`.

<details>

<summary>You don't like that name?!</summary>

In case you already have another function with the same name,
for example: the [`zed` command line editor](https://github.com/zsh-users/zsh/blob/master/Functions/Misc/zed),
just set the `ZED[name]` variable to something else before
sourcing the `zed.zsh` file.

```sh
ZED[name]=zedi
```

Then `zed` will become `zedi`, and you can do:

```sh
zedi load "${HOME}/darkside.sh"
```

</details>

#### `zed init`

Initialize

#### `zed load`

Load plugin

#### `zed done`

Finalize

#### `zed list`

List plugin-ids

#### `zed pull [plugin-id]`

Pull latest changes for plugins

#### `zed pull-self`

Pull latest changes for zed itself

## Alternatives

_(In alphabetical order of repository names)_

- [zsh-users/antigen](https://github.com/zsh-users/antigen)
- [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh)
- [sorin-ionescu/prezto](https://github.com/sorin-ionescu/prezto)
- [mattmc3/pz](https://github.com/mattmc3/pz)
- [agkozak/zcomet](https://github.com/agkozak/zcomet)
- [tarjoilija/zgen](https://github.com/tarjoilija/zgen)
- [jandamm/zgenom](https://github.com/jandamm/zgenom)
- [zimfw/zimfw](https://github.com/zimfw/zimfw)
- [zplug/zplug](https://github.com/zplug/zplug)
- [zpm-zsh/zpm](https://github.com/zpm-zsh/zpm)
- [...more](https://github.com/unixorn/awesome-zsh-plugins#frameworks)

## FAQ

- _**Q**: There are so many zsh plugin managers! Why should I care about this one?_

  _**A**:_ You probably shouldn't.

- _**Q**: What does this this offer that the others don't?_

  _**A**:_ Well, possibly nothing.

- _**Q**: What does this do differently?_

  _**A**:_ It doesn't really matter.

- _**Q**: Why does this freaking exist?_

  _**A**:_ Because, it does.

## License

Licensed under the MIT License. Check the [LICENSE](./LICENSE) file for details.
