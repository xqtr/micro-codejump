# codejump (Micro editor plugin)

`codejump` is a Micro editor plugin that provides fast navigation through source code by jumping between:

- Functions
- Classes
- Language-specific blocks
- Markdown headings

It is designed to mimic "structural navigation" features found in IDEs, but keep things lightweight and regex-based.


![list](https://github.com/xqtr/micro-codejump/blob/main/list.png)

---

## Features

### Code navigation
Jump between definitions in multiple languages:

- Python: `def`, `class`
- Go: `func`
- Rust: `fn`, `impl`, `trait`
- Pascal: `function`, `procedure`, `constructor`, `destructor`
- C/C++: function and class-like declarations
- Lua: `function`
- JavaScript / Java (basic heuristics)
- Markdown: headings (`#` through `######`)

---

### Commands

| Command | Action |
|--------|--------|
| `codejump` | Jump to any symbol using external analyzer + fzf F4|
| `defjumpdown` | Jump to next function/block CTRL+Down|
| `defjumpup` | Jump to previous function/block CTRL+Up|

---

### Default keybindings

- `F4` → `codejump`
- `Ctrl + Down` → next function/block
- `Ctrl + Up` → previous function/block

---

## Installation

### Manual install

Clone into Micro plugins directory:

```bash
git clone https://github.com/xqtr/micro-codejump ~/.config/micro/plug/codejump
```

Restart Micro.

## How it works

#### 1. Structural navigation (Lua-based)

The plugin scans the current buffer line-by-line using regex patterns to detect:

- function definitions
- class definitions
- markdown headings

It then moves the cursor to the next or previous match.

#### 2. FZF-based jump (external analyzer)

The codejump command uses an external Python script + fzf to:

- index the current file
- allow fuzzy selection
- jump directly to selected line

## Configuration

The analyzer path is computed automatically:

~/.config/micro/plug/codejump/code_analyzer.py

Make sure:

- fzf is installed
- python3 is available
- the analyzer script exists and is executable


### Supported languages
- Python
- Go
- Rust
- Pascal
- C/C++
- Lua	Basic
- Markdown


### Limitations
- Uses regex, not a real parser (no AST awareness)
- C/C++ detection is heuristic and may produce false positives
- Complex language constructs (nested functions, macros) may not be detected
- Performance depends on file size (linear scan)


### Motivation

- Micro is lightweight, but lacks IDE-style code structure navigation.

This plugin adds:

- fast jumping between logical blocks
- minimal dependencies
- extensibility via regex patterns
- optional fuzzy navigation via fzf

## License

MIT

## Author

Based on ideas from Tero Karvinen’s micro-jump plugin
Extended to be more visible appealed (fzf) and added functions to navigate via key bindinds, between functions.

XQTR // cp737.net 
