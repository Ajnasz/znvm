# ZNVM: Nodejs Version Manager for ZSH

Similar to [nvm-sh](https://github.com/nvm-sh/nvm) but meant to be faster (on startup at least).

## Install

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
znvm use default
# load version defined in .nvmrc
znvm hookwdchange
```

### Install in oh-my-zsh

```bash
cd $ZSH
git submodule add https://github.com/Ajnasz/znvm custom/plugins/znvm
```

Enable the `znvm` plugin in your `.zshrc`.

[How to enable plugins in oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh#plugins)

Load default nodejs version
```bash
# load default nodejs version
znvm use default
# load version defined in .nvmrc
znvm hookwdchange
```

## Configuration

The `ZNVM_DIR` environment variable, default value is `$HOME/.znvm`

```
ZNVM_DIR=$HOME/.znvm
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

### Autoload version which is defined in `.nvmrc`

```bash
znvm hookwdchange
```
