# ZNVM: Nodejs Version Manager for ZSH

Similar to [nvm](https://github.com/nvm-sh/nvm)

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
```

### Install in oh-my-zsh

```bash
cd $ZSH
git submodule add https://github.com/Ajnasz/znvm custom/plugins/znvm
```

Enable the `znvm` plugin in your `.zshrc`.

[How to enable plugins in oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh#plugins)
