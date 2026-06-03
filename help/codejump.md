# CODEJUMP - Jump through functions/classes in code

A tool to jump to code references, like functions, methods, classes etc. using fzf to list all of them and select one.

Supports the following languages:
- Python
- Pascal
- Go
- Java
- Javascript
- C++
- TypeScript
- Ruby
- Rust

## Keybindings

Use F4 to bring a list with fzf and select the reference you want to jump to.

Key bindings can be changed in $HOME/.config/micro/bindings.json

Default binding is 
```json
{ "F4": "command:jumpcode" }

```

## Requirements

Make sure you have `fzf` installed.# DEFJUMP - Jump through functions/classes in code

# DEFJUMPUP / DEFJUMPDOWN

## Keybindings

Use CTRL+Up or CTRL+Down to jump to a function/class statement inside the code or even headers in a markdown file.

Key bindings can be changed in $HOME/.config/micro/bindings.json

Default binding is 
```json
{ "Ctrl-Up": "command:defjumpup",
  "Ctrl-Down": "command:defjumpdown",
 }

```
