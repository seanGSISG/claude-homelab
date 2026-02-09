#!/bin/bash
# Test suite for lib/json.sh

# Note: Not using 'set -e' so test failures don't exit the script
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/json.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test assertion helper
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    ((TESTS_RUN++))

    if [[ "$expected" == "$actual" ]]; then
        echo "✓ PASS: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo "✗ FAIL: $test_name"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test JSON validity
assert_valid_json() {
    local json="$1"
    local test_name="$2"

    ((TESTS_RUN++))

    if echo "$json" | jq . >/dev/null 2>&1; then
        echo "✓ PASS: $test_name (valid JSON)"
        ((TESTS_PASSED++))
        return 0
    else
        echo "✗ FAIL: $test_name (invalid JSON)"
        echo "  JSON: $json"
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "=== Testing lib/json.sh ==="
echo

# === json_escape tests ===
echo "--- Testing json_escape() ---"

# Test 1: Simple string
result=$(json_escape "hello world")
expected='"hello world"'
assert_equals "$expected" "$result" "json_escape: simple string"

# Test 2: String with quotes
result=$(json_escape 'string with "quotes"')
expected='"string with \"quotes\""'
assert_equals "$expected" "$result" "json_escape: string with quotes"

# Test 3: String with newlines
result=$(json_escape $'line1\nline2')
expected='"line1\nline2"'
assert_equals "$expected" "$result" "json_escape: string with newlines"

# Test 4: String with backslashes
result=$(json_escape 'path\to\file')
expected='"path\\to\\file"'
assert_equals "$expected" "$result" "json_escape: string with backslashes"

# Test 5: Empty string
result=$(json_escape "")
expected='""'
assert_equals "$expected" "$result" "json_escape: empty string"

echo

# === json_array tests ===
echo "--- Testing json_array() ---"

# Test 1: Simple array
result=$(json_array "foo" "bar" "baz")
assert_valid_json "$result" "json_array: simple array"
expected='["foo","bar","baz"]'
result_normalized=$(echo "$result" | jq -c '.')
assert_equals "$expected" "$result_normalized" "json_array: content check"

# Test 2: Empty array
result=$(json_array)
expected='[]'
assert_equals "$expected" "$result" "json_array: empty array"

# Test 3: Array with special characters
result=$(json_array "item with spaces" "item-with-dashes" "item_with_underscores")
assert_valid_json "$result" "json_array: special characters"

# Test 4: Single item
result=$(json_array "single")
expected='["single"]'
result_normalized=$(echo "$result" | jq -c '.')
assert_equals "$expected" "$result_normalized" "json_array: single item"

echo

# === json_object tests ===
echo "--- Testing json_object() ---"

# Test 1: Simple object
result=$(json_object "name" "John" "age" "30")
assert_valid_json "$result" "json_object: simple object"

# Verify keys exist
name=$(echo "$result" | jq -r '.name')
age=$(echo "$result" | jq -r '.age')
assert_equals "John" "$name" "json_object: name field"
assert_equals "30" "$age" "json_object: age field"

# Test 2: Empty object
result=$(json_object)
expected='{}'
assert_equals "$expected" "$result" "json_object: empty object"

# Test 3: Object with special characters in values
result=$(json_object "path" "/usr/local/bin" "message" 'Error: "file not found"')
assert_valid_json "$result" "json_object: special characters in values"

# Test 4: Single key-value pair
result=$(json_object "status" "ok")
expected='{"status":"ok"}'
result_normalized=$(echo "$result" | jq -c '.')
assert_equals "$expected" "$result_normalized" "json_object: single pair"

echo

# === json_array_of_json tests ===
echo "--- Testing json_array_of_json() ---"

# Test 1: Array of objects
obj1='{"name":"Alice","age":25}'
obj2='{"name":"Bob","age":30}'
result=$(json_array_of_json "$obj1" "$obj2")
assert_valid_json "$result" "json_array_of_json: array of objects"

# Verify structure
count=$(echo "$result" | jq 'length')
assert_equals "2" "$count" "json_array_of_json: item count"

# Test 2: Empty array
result=$(json_array_of_json)
expected='[]'
assert_equals "$expected" "$result" "json_array_of_json: empty array"

# Test 3: Mixed JSON types
arr='[1,2,3]'
obj='{"key":"value"}'
result=$(json_array_of_json "$arr" "$obj")
assert_valid_json "$result" "json_array_of_json: mixed types"

echo

# === json_object_with_json tests ===
echo "--- Testing json_object_with_json() ---"

# Test 1: Object with nested object
nested='{"city":"NYC","zip":"10001"}'
result=$(json_object_with_json "name" '"John"' "address" "$nested")
assert_valid_json "$result" "json_object_with_json: nested object"

# Verify nested structure
city=$(echo "$result" | jq -r '.address.city')
assert_equals "NYC" "$city" "json_object_with_json: nested value access"

# Test 2: Object with array value
arr='[1,2,3]'
result=$(json_object_with_json "numbers" "$arr")
assert_valid_json "$result" "json_object_with_json: array value"

# Test 3: Empty object
result=$(json_object_with_json)
expected='{}'
assert_equals "$expected" "$result" "json_object_with_json: empty object"

echo

# === Integration test ===
echo "--- Integration Test ---"

# Build a complex nested structure
users=$(json_array_of_json \
    "$(json_object "name" "Alice" "role" "admin")" \
    "$(json_object "name" "Bob" "role" "user")")

config=$(json_object_with_json \
    "version" '"1.0"' \
    "users" "$users" \
    "enabled" 'true')

assert_valid_json "$config" "Integration: complex nested structure"

# Verify structure
version=$(echo "$config" | jq -r '.version')
user_count=$(echo "$config" | jq '.users | length')
first_user=$(echo "$config" | jq -r '.users[0].name')

assert_equals "1.0" "$version" "Integration: version field"
assert_equals "2" "$user_count" "Integration: user count"
assert_equals "Alice" "$first_user" "Integration: first user name"

echo

# === Summary ===
echo "==================================="
echo "Test Results:"
echo "  Total:  $TESTS_RUN"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "==================================="

if (( TESTS_FAILED > 0 )); then
    exit 1
else
    echo "✓ All tests passed!"
    exit 0
fi
