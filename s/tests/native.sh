#!/usr/bin/env bash
set -u

test_tmp="$(mktemp -d)"
passed=0
failed=0

check_native() {
  name="$1"
  expected="$2"
  source="s/tests/native/${name}.s"
  llvm="${test_tmp}/${name}.ll"
  binary="${test_tmp}/${name}"

  if ! racket tools/run.rkt s/tools/native.s "$source" "$llvm" >/dev/null; then
    echo "fail ${name}: compile"
    failed=$((failed + 1))
    return
  fi
  if ! clang "$llvm" -o "$binary" 2>/dev/null; then
    echo "fail ${name}: clang"
    failed=$((failed + 1))
    return
  fi

  "$binary"
  actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "pass ${name}: ${actual}"
    passed=$((passed + 1))
  else
    echo "fail ${name}: expected ${expected}, got ${actual}"
    failed=$((failed + 1))
  fi
}

check_output() {
  name="$1"
  expected="$2"
  source="s/tests/native/${name}.s"
  llvm="${test_tmp}/${name}.ll"
  binary="${test_tmp}/${name}"

  if ! racket tools/run.rkt s/tools/native.s "$source" "$llvm" >/dev/null; then
    echo "fail ${name}: compile"
    failed=$((failed + 1))
    return
  fi
  if ! clang "$llvm" -o "$binary" 2>/dev/null; then
    echo "fail ${name}: clang"
    failed=$((failed + 1))
    return
  fi

  actual="$($binary)"
  if [[ "$actual" == "$expected" ]]; then
    echo "pass ${name}: output"
    passed=$((passed + 1))
  else
    echo "fail ${name}: output mismatch"
    failed=$((failed + 1))
  fi
}

check_native add 12
check_native sub 5
check_native mul 42
check_native div 5
check_native gt-true 1
check_native gt-false 0
check_native lt-true 1
check_native lt-false 0
check_native eq-true 1
check_native eq-false 0
check_output skill "hello from skill"
check_output skill-arg "Candy"
check_output drum $'tick\ntick\ntick'
check_native drum-number 5
check_native group-count 3
check_native group-item 7
check_native group-add 9
check_native group-add-count 3
check_output string-escape $'quote:" slash:\\ line:\nnext'
check_native box 7
check_native box-default 5
check_native box-order 7
check_native box-set 9
check_native box-skill 7
check_native box-change 9
check_native box-change-many-x 7
check_native box-change-many-y 9
check_native box-chain 12

echo "native passed=${passed}"
echo "native failed=${failed}"

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
