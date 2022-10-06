# ZNVM: Nodejs Version Manager for ZSH

Similar to [nvm-sh](https://github.com/nvm-sh/nvm) but meant to be faster (on startup at least).

## Install

### Dependencies

You shell must be [zsh](https://www.zsh.org/)

The following commands also needed for operation:
- `curl`
- `awk`
- `tail`
- `head`
- `cut`
- `sort`
- `uniq`

### General installation

```
git clone https://github.com/Ajnasz/znvm $HOME/src/znvm
```

Edit you .zshrc and the following line to enable the plugin:

```bash
# enable znvm plugin
. $HOME/src/znvm/znvm.plugin.zsh
# enable autocompletion for znvm
fpath+=$HOME/src/znvm
# load default nodejs version
# but only if it's not set (for example it will be set if you use tmux)
# remove the if statement if you want to make sure the default version used in a new shell
if ! znvm current > /dev/null
then
	znvm use default
fi
# load version defined in .nvmrc
znvm hookwdchange
```

### Install in oh-my-zsh

```bash
cd $ZSH
git submodule add https://github.com/Ajnasz/znvm custom/plugins/znvm
```

### Install in [zgenom](https://github.com/jandamm/zgenom)

Add `zgenom load Ajnasz/znvm` in your `.zshrc` with your other `zgenom load` commands.

#### Enable the `znvm` plugin in your `.zshrc`.

[How to enable plugins in oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh#plugins)

### Load default nodejs version

```bash
# load default nodejs version
znvm use default
# load version defined in .nvmrc
znvm hookwdchange
```

## Configuration

The `ZNVM_DIR` environment variable, default value is `$HOME/.znvm`

```
ZNVM_DIR="$HOME/.znvm"
```

The `ZNVM_SEARCH_FILENAMES` environment variable is a list of filenames (separated by space) znvm will look for whenever it executes the `chpwd` hook listener. Default value is `.znvmrc .nvmrc Dockerfile`

To disable Dockerfile read remove it from the list:

```
ZNVM_SEARCH_FILENAMES=".znvmrc .nvmrc"
```
## Usage

### Install a nodejs version

To install the latest nodejs v12:

```bash
znvm install v12
```

To install nodejs v8.1.1

```bash
znvm install v8.1.1
```

### Create or update an alias

```bash
znvm alias default v12
```

### Load a version

```bash
znvm use v12
```

Use a default version

```bash
znvm use default
```

### Auto use from `.znvmrc`, `.nvmrc` or `Dockerfile` files

Add the following line to the .zshrc

```bash
znvm hookwdchange
```

The hook will traverse directory structure upwards from the current directory looking for the files defined in `$ZNVM_SEARCH_FILENAMES` every time you change directory.

That will add a hook, which executes every time you change directory. The hook listener will search `.znvmrc`, `.nvmrc` and `Dockerfile` in the directory you entered to. If no file found, it will try to find it in the parent directory until it reaches the root directory.

When it searches in a `Dockerfile`, it will try to extract the version number from `FROM node:` line.
