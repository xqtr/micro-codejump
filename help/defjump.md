# DEFJUMP - Jump through functions/classes in code

A tool to jump to code references, like functions, methods, classes etc.

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

Use CTRL+Up or CTRL+Down to jump to a function/class statement inside the code or even headers in a markdown file.

Key bindings can be changed in $HOME/.config/micro/bindings.json

Default binding is 
```json
{ "Ctrl-Up": "command:defjumpup",
  "Ctrl-Down": "command:defjumpdown",
 }

```
