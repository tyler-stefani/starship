# Starship for Fish 🚀🐟

Implements the [Starship](https://github.com/starship/starship) prompt as a plugin for [Fish](https://github.com/fish-shell/fish-shell)

## Installation
```
fisher install tyler-stefani/starship
```

## Asynchronous prompts
The biggest advantage of using this prompt over adding `starship init fish | source` to config is the ability for this plugin to display prompts asynchronously. Inspired by [Tide](https://github.com/IlanCosman/tide) and [async-prompt](https://github.com/acomagu/fish-async-prompt) but built to work with the universal configuration of Starship.
