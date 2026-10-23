# Godot Engine Version Specification

## Target Engine
- **Engine**: Godot Engine
- **Version**: `4.0.stable.official.92bee43ad`
- **Config Version**: 5 (Godot 4.x standard)
- **Renderer**: Forward Plus
- **Executable Paths**:
  - Windows Headless/Runner: `C:\Godot\godot.exe`
  - Windows Console Output: `C:\Godot\Godot_v4.0-stable_win64_console.exe`

## Critical Godot 4.0 Compatibility Rules
1. **No Static `has_method` on Class Names**: In Godot 4.0, calling `ClassName.has_method("func_name")` directly produces a fatal compiler parser error (`Cannot call non-static function 'has_method()' on the class directly`). Always call static functions directly or test instances.
2. **Lambda Primitive Variable Capture**: Primitive variables (`bool`, `int`, `float`) captured in closures are captured by-value. For mutable capture, use containers like `var flag = [false]; func(): flag[0] = true`.
3. **Callable Binding Order**: `Callable.bind(...)` appends bound arguments *after* the arguments passed by the caller.
4. **All Tests in `res://tests/`**: All test suites must reside under `res://tests/` as `test_*.gd`. No test scripts in the project root.
5. **Headless Execution Syntax**:
   ```powershell
   & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path c:\dev\UniCORE -s res://tests/<suite_name>.gd
   ```
