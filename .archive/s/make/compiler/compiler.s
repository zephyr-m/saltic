use core
use s.make.compiler.lexer.scanner
use s.make.compiler.syntax.parser
use s.make.compiler.semantics.checker
use s.make.compiler.emit.emitter
use s.make.compiler.emit.llvm

CompilerIn = Box {
    source = ""
    path = ""
}

CompilerOut = Box {
    ast = none
    ir = []
    llvm = ""
    diagnostics = []
    path = ""
    scan_errors = 0
    parse_errors = 0
    check_errors = 0
}

CompilerContract = Box {
    input = CompilerIn {}
    output = CompilerOut {}
}

skill s_compiler_contract() {
    out CompilerContract {}
}

skill compiler_scan(source_text, module_path) {
    out scanner_scan(source_text, module_path)
}

skill compiler_parse(tokens, module_path) {
    out parser_parse_module(tokens, module_path)
}

skill compiler_check(ast, module_path) {
    out checker_check_program(ast, module_path)
}

skill compiler_emit_stage(ast) {
    out compiler_emit(ast)
}

skill compiler_compile(source, module_path) {
    @input_source = source
    @result_ast = none
    @result_ir = []
    @result_llvm = ""
    @result_diagnostics = []
    @blocked = no
    @scan_result = ScannerOut {}
    @parse_result = ParserOut {}
    @check_result = CheckerOut {}
    @emit_result = EmitOut {}
    @scan_errors = 0
    @parse_errors = 0
    @check_errors = 0
    scan_result = scanner_scan(input_source, module_path)
    scan_errors = core.group.count(scan_result.diagnostics)
    (scan_errors > 0) {
        result_diagnostics = scan_result.diagnostics
        blocked = yes
    }

    (blocked == no) {
        parse_result = compiler_parse(scan_result.tokens, module_path)
        parse_errors = core.group.count(parse_result.diagnostics)
        (parse_errors > 0) {
            result_diagnostics = parse_result.diagnostics
            blocked = yes
        }
    }

    (blocked == no) {
        check_result = compiler_check(parse_result.ast, module_path)
        result_ast = check_result.checked
        check_errors = core.group.count(check_result.diagnostics)
        (check_errors > 0) {
            result_diagnostics = check_result.diagnostics
            blocked = yes
        }
    }

    (blocked == no) {
        emit_result = compiler_emit_stage(result_ast)
        result_ir = emit_result.instructions
        @llvm_result = llvm_emit(result_ir)
        result_llvm = llvm_result.text
    }

    out CompilerOut {
        ast = result_ast
        ir = result_ir
        llvm = result_llvm
        diagnostics = result_diagnostics
        path = module_path
        scan_errors = scan_errors
        parse_errors = parse_errors
        check_errors = check_errors
    }
}
