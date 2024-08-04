## Usage

Execute an example script
```
zig build run -- examples/test.lisp
```

Run tests
```
zig test src/Evaluator.zig
```

## Features

- [x] lexer and parser iterators (lexer yields tokens and parser yields top-level expressions)
- [x] several builtin functions including `quote` and `eval`.
- [x] anonymous functions
- [x] lexical scope
- [x] `Value` methods to make traversing `Cons` cells less error-prone
- [ ] garbage collection
- [ ] user-defined macros
- [ ] continuations
- [ ] error messages
