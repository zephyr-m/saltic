use core
use token

ScannerIn = Box {
    source = ""
    path = ""
}

ScannerOut = Box {
    tokens = []
    diagnostics = []
    path = ""
}

ScannerContract = Box {
    input = ScannerIn {}
    output = ScannerOut {}
}

skill s_compiler_scanner_contract() {
    out ScannerContract {}
}

skill s_compiler_scanner_stub(in) {
    out ScannerOut {
        tokens = []
        diagnostics = []
        path = in.path
    }
}
