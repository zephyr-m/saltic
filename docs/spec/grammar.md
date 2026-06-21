# Грамматика v0.1

Этот документ фиксирует первое подмножество S, которое должен покрывать parser.

Цель этапа: распарсить `examples/bootstrap/basic.s` и получить читаемый AST.

## Поддерживаемые конструкции

```text
program      = "program" "(" params? ")" block
item         = use | const | enum | skill | program

use          = "use" path
const        = Ident "=" expr
enum         = Ident "=" "enum" "{" Ident ("," Ident)* ","? "}"
skill        = "skill" Ident "(" params? ")" block
params       = Ident ("," Ident)*

block        = "{" stmt* "}"
stmt         = var | assign | out | if | switch | drum | expr
var          = "@" Ident "=" expr
assign       = Ident "=" expr
out          = "out" expr
if           = "(" expr ")" block
switch       = "(" expr ")" "{" case* "}"
case         = "." Ident "=>" expr ","?
drum         = "drum" "(" expr ")" block

expr         = rescue | binary | call | path | literal | enum-value
rescue       = expr "rescue" "|" Ident "|" block
binary       = expr ("==" | ">" | "<" | "+" | "-" | "*" | "/") expr
call         = expr "(" args? ")"
args         = expr ("," expr)*
path         = Ident ("." Ident)*
enum-value   = "." Ident
literal      = Number | String | "none"
```

## Приоритеты операторов

```text
* /
+ -
== > <
rescue
```

## Намеренные ограничения первого parser

- `Box`, `union`, typed declarations, arrays и `try` пока не входят в MVP parser.
- `drum` пока поддерживает только форму `drum (N) { ... }`.
- Комментарии и `@note` пока не финализированы и не парсятся.
- `use std` реализован как минимальный import для `std.*` bridge.
- Parser проверяет форму программы, но не проверяет типы, scope и существование имён.

## Команды

```bash
racket tools/parse.rkt examples/bootstrap/basic.s
just parse
just test
```
