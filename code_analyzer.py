#!/usr/bin/env python3
"""
Multi-language code analyzer that extracts functions, methods, and classes
with line numbers and tree view hierarchy.
"""

import sys
import re
import json
from pathlib import Path
from enum import Enum

class Language(Enum):
    PYTHON = "python"
    RUST = "rust"
    GO = "go"
    JAVASCRIPT = "javascript"
    TYPESCRIPT = "typescript"
    JAVA = "java"
    PASCAL = "pascal"
    CPP = "cpp"
    RUBY = "ruby"

class SymbolTreeBuilder:
    def __init__(self, language):
        self.language = language
        self.symbols = []
        self.current_path = []
    
    def add_symbol(self, name, sym_type, line, end_line=None, parent=None):
        symbol = {
            'name': name,
            'type': sym_type,
            'line': line,
            'end_line': end_line,
            'parent': parent,
            'depth': len(self.current_path),
            'children': []
        }
        
        if self.current_path:
            self.current_path[-1]['children'].append(symbol)
        else:
            self.symbols.append(symbol)
        
        return symbol
    
    def enter_scope(self, symbol):
        self.current_path.append(symbol)
    
    def exit_scope(self):
        if self.current_path:
            self.current_path.pop()
    
    def get_flat_list(self):
        flat_list = []
        
        def flatten(symbol_list, prefix=""):
            for i, sym in enumerate(symbol_list):
                is_last = (i == len(symbol_list) - 1)
                
                if prefix:
                    if is_last:
                        current_prefix = prefix + "└── "
                        child_prefix = prefix + "    "
                    else:
                        current_prefix = prefix + "├── "
                        child_prefix = prefix + "│   "
                else:
                    current_prefix = ""
                    child_prefix = "    "
                
                icon = self._get_icon(sym['type'])
                flat_list.append({
                    'display': f"{sym['line']:6d}:{current_prefix}{icon}{sym['name']}",
                    'name': sym['name'],
                    'type': sym['type'],
                    'line': sym['line'],
                    'depth': sym['depth']
                })
                
                if sym['children']:
                    flatten(sym['children'], child_prefix)
        
        flatten(self.symbols)
        return flat_list
    
    def _get_icon(self, sym_type):
        icons = {
            'class': 'cls ',
            'struct': 'str ',
            'interface': 'int ',
            'trait': 'trt ',
            'method': 'met ',
            'function': 'fun ',
            'proc': 'fun ',  # Pascal procedure
            'constructor': 'con ',
            'destructor': 'des '
        }
        return icons.get(sym_type, '• ')

class CodeAnalyzer:
    def __init__(self, language):
        self.language = language
        self.builder = SymbolTreeBuilder(language)
    
    def analyze(self, content):
        if self.language == Language.PYTHON:
            return self._analyze_python(content)
        elif self.language == Language.RUST:
            return self._analyze_rust(content)
        elif self.language == Language.GO:
            return self._analyze_go(content)
        elif self.language == Language.JAVASCRIPT:
            return self._analyze_javascript(content)
        elif self.language == Language.TYPESCRIPT:
            return self._analyze_typescript(content)
        elif self.language == Language.JAVA:
            return self._analyze_java(content)
        elif self.language == Language.PASCAL:
            return self._analyze_pascal(content)
        elif self.language == Language.CPP:
            return self._analyze_cpp(content)
        elif self.language == Language.RUBY:
            return self._analyze_ruby(content)
        else:
            raise ValueError(f"Unsupported language: {self.language}")
    
    def _analyze_python(self, content):
        """Python parser using AST"""
        try:
            import ast
            tree = ast.parse(content)
            
            def process_node(node, parent=None):
                if isinstance(node, ast.ClassDef):
                    sym = self.builder.add_symbol(
                        node.name, 'class', node.lineno, node.end_lineno, parent
                    )
                    self.builder.enter_scope(sym)
                    for child in node.body:
                        process_node(child, sym)
                    self.builder.exit_scope()
                
                elif isinstance(node, ast.FunctionDef):
                    sym_type = 'method' if isinstance(parent, ast.ClassDef) else 'function'
                    sym = self.builder.add_symbol(
                        node.name, sym_type, node.lineno, node.end_lineno, parent
                    )
                    self.builder.enter_scope(sym)
                    for child in node.body:
                        if isinstance(child, (ast.FunctionDef, ast.ClassDef)):
                            process_node(child, sym)
                    self.builder.exit_scope()
            
            for node in tree.body:
                process_node(node)
            return True
            
        except Exception as e:
            print(f"Python parsing error: {e}", file=sys.stderr)
            return False
    
    def _analyze_rust(self, content):
        """Rust parser using regex patterns (simplified - for production use syn/rust-analyzer)"""
        lines = content.split('\n')
        
        # Patterns for Rust
        struct_pattern = re.compile(r'^\s*(pub\s+)?struct\s+(\w+)')
        enum_pattern = re.compile(r'^\s*(pub\s+)?enum\s+(\w+)')
        trait_pattern = re.compile(r'^\s*(pub\s+)?trait\s+(\w+)')
        impl_pattern = re.compile(r'^\s*impl\s+(\w+)')
        fn_pattern = re.compile(r'^\s*(pub\s+)?fn\s+(\w+)\s*\(')
        
        current_impl = None
        brace_depth = 0
        
        for i, line in enumerate(lines, 1):
            # Check for impl blocks
            impl_match = impl_pattern.search(line)
            if impl_match and '{' in line:
                current_impl = impl_match.group(1)
                self.builder.add_symbol(current_impl, 'impl', i, parent=None)
                brace_depth += line.count('{')
                continue
            
            # Check for struct/enum/trait
            struct_match = struct_pattern.search(line)
            if struct_match:
                self.builder.add_symbol(struct_match.group(2), 'struct', i)
                continue
            
            enum_match = enum_pattern.search(line)
            if enum_match:
                self.builder.add_symbol(enum_match.group(2), 'enum', i)
                continue
            
            trait_match = trait_pattern.search(line)
            if trait_match:
                self.builder.add_symbol(trait_match.group(2), 'trait', i)
                continue
            
            # Check for functions
            fn_match = fn_pattern.search(line)
            if fn_match:
                fn_name = fn_match.group(2)
                sym_type = 'method' if current_impl else 'function'
                self.builder.add_symbol(fn_name, sym_type, i)
            
            # Track brace depth
            brace_depth += line.count('{')
            brace_depth -= line.count('}')
            if brace_depth == 0:
                current_impl = None
        
        return True
    
    def _analyze_go(self, content):
        """Go parser using regex patterns"""
        lines = content.split('\n')
        
        func_pattern = re.compile(r'^\s*func\s+(\w+)')
        method_pattern = re.compile(r'^\s*func\s+\([^)]+\)\s+(\w+)')
        type_pattern = re.compile(r'^\s*type\s+(\w+)\s+(struct|interface)')
        
        for i, line in enumerate(lines, 1):
            type_match = type_pattern.search(line)
            if type_match:
                self.builder.add_symbol(type_match.group(1), 'type', i)
                continue
            
            method_match = method_pattern.search(line)
            if method_match:
                self.builder.add_symbol(method_match.group(1), 'method', i)
                continue
            
            func_match = func_pattern.search(line)
            if func_match and 'func' in line and '(' in line:
                self.builder.add_symbol(func_match.group(1), 'function', i)
        
        return True
    
    def _analyze_javascript(self, content):
        """JavaScript parser (ES6)"""
        lines = content.split('\n')
        
        class_pattern = re.compile(r'^\s*class\s+(\w+)')
        func_pattern = re.compile(r'^\s*(?:export\s+)?(?:async\s+)?function\s+(\w+)\s*\(')
        arrow_pattern = re.compile(r'^\s*(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\(?[^)]*\)?\s*=>')
        method_pattern = re.compile(r'^\s*(\w+)\s*\([^)]*\)\s*\{')
        
        in_class = False
        
        for i, line in enumerate(lines, 1):
            class_match = class_pattern.search(line)
            if class_match:
                self.builder.add_symbol(class_match.group(1), 'class', i)
                in_class = True
                continue
            
            if in_class and method_pattern.search(line) and not line.strip().startswith('//'):
                method_match = method_pattern.search(line)
                if method_match:
                    self.builder.add_symbol(method_match.group(1), 'method', i)
            
            func_match = func_pattern.search(line)
            if func_match:
                self.builder.add_symbol(func_match.group(1), 'function', i)
            
            arrow_match = arrow_pattern.search(line)
            if arrow_match:
                self.builder.add_symbol(arrow_match.group(1), 'function', i)
            
            # Reset class flag
            if '}' in line and in_class:
                in_class = False
        
        return True
    
    def _analyze_typescript(self, content):
        """TypeScript parser (simplified)"""
        lines = content.split('\n')
        
        class_pattern = re.compile(r'^\s*(?:export\s+)?class\s+(\w+)')
        interface_pattern = re.compile(r'^\s*(?:export\s+)?interface\s+(\w+)')
        type_pattern = re.compile(r'^\s*(?:export\s+)?type\s+(\w+)')
        func_pattern = re.compile(r'^\s*(?:export\s+)?function\s+(\w+)\s*\(')
        method_pattern = re.compile(r'^\s*(\w+)\s*\([^)]*\)\s*:\s*\w+\s*\{')
        
        in_class = False
        
        for i, line in enumerate(lines, 1):
            class_match = class_pattern.search(line)
            if class_match:
                self.builder.add_symbol(class_match.group(1), 'class', i)
                in_class = True
                continue
            
            interface_match = interface_pattern.search(line)
            if interface_match:
                self.builder.add_symbol(interface_match.group(1), 'interface', i)
                continue
            
            type_match = type_pattern.search(line)
            if type_match:
                self.builder.add_symbol(type_match.group(1), 'type', i)
                continue
            
            if in_class and method_pattern.search(line):
                method_match = method_pattern.search(line)
                if method_match:
                    self.builder.add_symbol(method_match.group(1), 'method', i)
            
            func_match = func_pattern.search(line)
            if func_match:
                self.builder.add_symbol(func_match.group(1), 'function', i)
            
            if '}' in line and in_class:
                in_class = False
        
        return True
    
    def _analyze_java(self, content):
        """Java parser"""
        lines = content.split('\n')
        
        class_pattern = re.compile(r'^\s*(?:public|private|protected)?\s+class\s+(\w+)')
        interface_pattern = re.compile(r'^\s*(?:public|private|protected)?\s+interface\s+(\w+)')
        method_pattern = re.compile(r'^\s*(?:public|private|protected)?\s+(?:static\s+)?(?:[\w<>[\]]+\s+)?(\w+)\s*\([^)]*\)\s*\{')
        
        in_class = False
        
        for i, line in enumerate(lines, 1):
            class_match = class_pattern.search(line)
            if class_match and '{' in line:
                self.builder.add_symbol(class_match.group(1), 'class', i)
                in_class = True
                continue
            
            interface_match = interface_pattern.search(line)
            if interface_match:
                self.builder.add_symbol(interface_match.group(1), 'interface', i)
                continue
            
            if in_class:
                method_match = method_pattern.search(line)
                if method_match and not method_match.group(1) in ['if', 'while', 'for', 'switch']:
                    self.builder.add_symbol(method_match.group(1), 'method', i)
            
            if '}' in line and in_class:
                brace_count = line.count('}') - line.count('{')
                if brace_count > 0:
                    in_class = False
        
        return True
    
    def _analyze_pascal(self, content):
        """Pascal/Delphi parser (Free Pascal compatible)"""
        lines = content.split('\n')
        
        unit_pattern = re.compile(r'^\s*[uU]nit\s+(\w+);')
        program_pattern = re.compile(r'^\s*[pP]rogram\s+(\w+);')
        class_pattern = re.compile(r'^\s*[tT]ype\s+(\w+)\s*=\s*class')
        interface_pattern = re.compile(r'^\s*[tT]ype\s+(\w+)\s*=\s*interface')
        procedure_pattern = re.compile(r'^\s*[pP]rocedure\s+(\w+)')
        function_pattern = re.compile(r'^\s*[fF]unction\s+(\w+)')
        constructor_pattern = re.compile(r'^\s*[cC]onstructor\s+(\w+)')
        destructor_pattern = re.compile(r'^\s*[dD]estructor\s+(\w+)')
        
        in_class = False
        current_class = None
        
        for i, line in enumerate(lines, 1):
            unit_match = unit_pattern.search(line)
            if unit_match:
                self.builder.add_symbol(unit_match.group(1), 'unit', i)
                continue
            
            program_match = program_pattern.search(line)
            if program_match:
                self.builder.add_symbol(program_match.group(1), 'program', i)
                continue
            
            class_match = class_pattern.search(line)
            if class_match:
                current_class = class_match.group(1)
                self.builder.add_symbol(current_class, 'class', i)
                in_class = True
                continue
            
            interface_match = interface_pattern.search(line)
            if interface_match:
                self.builder.add_symbol(interface_match.group(1), 'interface', i)
                in_class = True
                continue
            
            if in_class:
                constructor_match = constructor_pattern.search(line)
                if constructor_match:
                    self.builder.add_symbol(constructor_match.group(1), 'constructor', i)
                    continue
                
                destructor_match = destructor_pattern.search(line)
                if destructor_match:
                    self.builder.add_symbol(destructor_match.group(1), 'destructor', i)
                    continue
                
                procedure_match = procedure_pattern.search(line)
                if procedure_match:
                    self.builder.add_symbol(procedure_match.group(1), 'method', i)
                    continue
                
                function_match = function_pattern.search(line)
                if function_match:
                    self.builder.add_symbol(function_match.group(1), 'method', i)
                    continue
            
            # Top-level procedures/functions
            procedure_match = procedure_pattern.search(line)
            if procedure_match and not in_class:
                self.builder.add_symbol(procedure_match.group(1), 'proc', i)
            
            function_match = function_pattern.search(line)
            if function_match and not in_class:
                self.builder.add_symbol(function_match.group(1), 'function', i)
            
            # End of class
            if in_class and ('end;' in line.lower() or 'end.' in line.lower()):
                in_class = False
        
        return True
    
    def _analyze_cpp(self, content):
        """C++ parser (simplified)"""
        lines = content.split('\n')
        
        class_pattern = re.compile(r'^\s*class\s+(\w+)')
        struct_pattern = re.compile(r'^\s*struct\s+(\w+)')
        func_pattern = re.compile(r'^\s*[\w\*&<>]+\s+(\w+)\s*\([^)]*\)\s*\{')
        method_pattern = re.compile(r'^\s*[\w\*&<>]+\s+(\w+)::(\w+)\s*\([^)]*\)\s*\{')
        
        for i, line in enumerate(lines, 1):
            class_match = class_pattern.search(line)
            if class_match:
                self.builder.add_symbol(class_match.group(1), 'class', i)
                continue
            
            struct_match = struct_pattern.search(line)
            if struct_match:
                self.builder.add_symbol(struct_match.group(1), 'struct', i)
                continue
            
            method_match = method_pattern.search(line)
            if method_match:
                self.builder.add_symbol(f"{method_match.group(1)}::{method_match.group(2)}", 'method', i)
                continue
            
            func_match = func_pattern.search(line)
            if func_match and not line.strip().startswith('if') and not line.strip().startswith('for'):
                self.builder.add_symbol(func_match.group(1), 'function', i)
        
        return True
    
    def _analyze_ruby(self, content):
        """Ruby parser"""
        lines = content.split('\n')
        
        class_pattern = re.compile(r'^\s*class\s+(\w+)')
        module_pattern = re.compile(r'^\s*module\s+(\w+)')
        def_pattern = re.compile(r'^\s*def\s+(\w+)')
        def_self_pattern = re.compile(r'^\s*def\s+self\.(\w+)')
        
        in_class = False
        current_class = None
        
        for i, line in enumerate(lines, 1):
            class_match = class_pattern.search(line)
            if class_match:
                current_class = class_match.group(1)
                self.builder.add_symbol(current_class, 'class', i)
                in_class = True
                continue
            
            module_match = module_pattern.search(line)
            if module_match:
                self.builder.add_symbol(module_match.group(1), 'module', i)
                continue
            
            if in_class:
                def_match = def_pattern.search(line)
                if def_match:
                    self.builder.add_symbol(def_match.group(1), 'method', i)
                    continue
                
                def_self_match = def_self_pattern.search(line)
                if def_self_match:
                    self.builder.add_symbol(def_self_match.group(1), 'class_method', i)
            else:
                def_match = def_pattern.search(line)
                if def_match:
                    self.builder.add_symbol(def_match.group(1), 'function', i)
            
            if in_class and ('end' in line and line.strip() == 'end'):
                in_class = False
        
        return True

def detect_language(filepath):
    """Detect language from file extension"""
    ext = Path(filepath).suffix.lower()
    
    language_map = {
        '.py': Language.PYTHON,
        '.rs': Language.RUST,
        '.go': Language.GO,
        '.js': Language.JAVASCRIPT,
        '.mjs': Language.JAVASCRIPT,
        '.ts': Language.TYPESCRIPT,
        '.java': Language.JAVA,
        '.pas': Language.PASCAL,
        '.pp': Language.PASCAL,
        '.dpr': Language.PASCAL,
        '.cpp': Language.CPP,
        '.cc': Language.CPP,
        '.cxx': Language.CPP,
        '.hpp': Language.CPP,
        '.rb': Language.RUBY,
    }
    
    return language_map.get(ext, None)

def main():
    if len(sys.argv) < 2:
        print("Usage: code_analyzer.py <file> [language] [format]", file=sys.stderr)
        print("Languages: auto-detect, python, rust, go, javascript, typescript, java, pascal, cpp, ruby", file=sys.stderr)
        print("Formats: tree, json, micro, simple", file=sys.stderr)
        sys.exit(1)
    
    filepath = sys.argv[1]
    
    # Detect or get language
    if len(sys.argv) >= 3 and sys.argv[2] != 'auto':
        try:
            language = Language(sys.argv[2].lower())
        except ValueError:
            print(f"Unsupported language: {sys.argv[2]}", file=sys.stderr)
            sys.exit(1)
    else:
        language = detect_language(filepath)
        if not language:
            print(f"Could not detect language for {filepath}", file=sys.stderr)
            sys.exit(1)
    
    format_type = sys.argv[3] if len(sys.argv) >= 4 else 'tree'
    
    if not Path(filepath).exists():
        print(f"File not found: {filepath}", file=sys.stderr)
        sys.exit(1)
    
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    analyzer = CodeAnalyzer(language)
    success = analyzer.analyze(content)
    
    if success:
        if format_type == 'json':
            flat_list = analyzer.builder.get_flat_list()
            print(json.dumps(flat_list, indent=2))
        elif format_type == 'micro':
            flat_list = analyzer.builder.get_flat_list()
            for sym in flat_list:
                print(f"{sym['depth']}|{sym['name']}|{sym['type']}|{sym['line']}|{sym['display']}")
        else:  # tree or simple
            flat_list = analyzer.builder.get_flat_list()
            for sym in flat_list:
                print(sym['display'])
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
