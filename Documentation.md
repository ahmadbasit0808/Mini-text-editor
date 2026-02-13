# Mini Text Editor (8086 Assembly) - Complete Documentation

## Project Overview

A complete mini text editor written in 8086 x86 assembly language using the Intel syntax. This program runs in DOS/emulated environments (like emu8086) and provides a full-featured text editing capability with file I/O operations.

---

## Table of Contents

1. [Architecture & Data Structures](#architecture--data-structures)
2. [Macros](#macros)
3. [Main Procedures](#main-procedures)
4. [Editing Features](#editing-features)
5. [File Operations](#file-operations)
6. [Complete Feature List](#complete-feature-list)
7. [Known Limitations & Fixes Applied](#known-limitations--fixes-applied)

---

## Architecture & Data Structures

### Memory Model

- **Model**: SMALL (64KB code segment, 64KB data segment)
- **Stack**: 256 bytes

### Data Segment (.DATA)

#### Display Messages

```assembly
menu_title      db '=== MINI TEXT EDITOR ===$'
menu_new        db '1. Create New File$'
menu_load       db '2. Load Existing File$'
menu_exit       db '3. Exit$'
menu_choice     db 'Enter your choice (1-3): $'
prompt_filename db 'Enter filename (max 12 chars): $'
prompt_save     db 'Press CTRL+S to save, ESC to exit$'
msg_saved       db 'File saved successfully!$'
msg_error       db 'Error: Could not open file!$'
msg_loaded      db 'File loaded successfully!$'
```

All messages end with '$' which is required for DOS int 21h function 09h (print string).

#### File & Buffer Variables

```assembly
filename        db 13 dup(0)      ; 12-char filename + null terminator
file_handle     dw ?              ; DOS file handle returned from open/create
file_buffer     db 2000 dup('$')  ; 2000-byte buffer for content (unused - kept for future)
edit_buffer     db 2000 dup('$')  ; 2000-byte editing buffer (primary buffer)
```

#### Cursor State Variables

```assembly
cursor_row      db 5              ; Current row (rows 0-4 reserved for UI, 5-24 for editing)
cursor_col      db 0              ; Current column (0-79 for 80-column mode)
```

#### Other Variables

```assembly
choice          db ?              ; Menu selection (stores user's choice)
char_count      dw ?              ; Total character count in edit_buffer
```

---

## Macros

Macros are reusable code patterns that simplify common operations.

### 1. `print_string` - Print a string to console

```assembly
print_string MACRO msg
    mov dx, offset msg
    mov ah, 09h        ; DOS int 21h function 09h
    int 21h
ENDM
```

**Usage**: `print_string menu_title`
**Function**: Uses DOS interrupt to print a $ -terminated string to stdout
**Note**: String must end with '$' character

---

### 2. `print_newline` - Print CR+LF (carriage return + line feed)

```assembly
print_newline MACRO
    mov dl, 10        ; Line feed (LF)
    mov ah, 02h       ; DOS int 21h function 02h (print char)
    int 21h
    mov dl, 13        ; Carriage return (CR)
    mov ah, 02h
    int 21h
ENDM
```

**Function**: Prints both LF and CR for proper line wrapping
**Note**: Order is LF first, then CR (non-standard but works)

---

### 3. `clear_screen` - Clear entire 80x25 screen

```assembly
clear_screen MACRO
    mov ah, 02h       ; BIOS int 10h function 02h (set cursor)
    mov dh, 0         ; row 0
    mov dl, 0         ; column 0
    mov bh, 0         ; video page 0
    int 10h
    mov ah, 0Ah       ; BIOS int 10h function 0Ah (write char at cursor)
    mov al, 00h       ; null character (blank space)
    mov cx, 2000      ; 80 columns × 25 rows
    int 10h
ENDM
```

**Function**: Moves cursor to top-left, then writes 2000 blank characters to clear screen

---

### 4. `set_cursor` - Position cursor at specific row/column

```assembly
set_cursor MACRO row, col
    mov ah, 02h       ; BIOS int 10h function 02h
    mov dh, row       ; row (DH = row)
    mov dl, col       ; column (DL = column)
    mov bh, 0         ; video page 0
    int 10h
ENDM
```

**Usage**: `set_cursor 5, 0` - moves cursor to row 5, column 0

---

## Main Procedures

### 1. `display_menu` PROC - Show main menu

```
INPUT:  None
OUTPUT: Displays menu on screen
```

**Function Flow**:

1. Clear screen with `clear_screen` macro
2. Print menu title with spacing
3. Print three options (New, Load, Exit)
4. Print prompt for user choice
5. Return to caller

---

### 2. `get_choice` PROC - Get user's menu selection

```
INPUT:  None
OUTPUT: Stores user's character in 'choice' variable
```

**Function Flow**:

1. Use DOS int 21h function 01h to read one character from keyboard
2. Store it in `choice` variable
3. Print newline to move to next line
4. Return

**Notes**:

- Reads directly from keyboard without echo (int 21h does basic echo)
- Simplest input method, no validation

---

### 3. `get_filename` PROC - Get filename from user with input validation

```
INPUT:  None (prompts user for input)
OUTPUT: Stores filename in 'filename' buffer
```

**Features**:

- **Maximum length**: 12 characters (enforced)
- **Character validation**: Only accepts ASCII 32-126 (printable characters)
- **Special keys handled**:
  - Enter/Return: Finishes input
  - Backspace: Deletes last character
  - Arrow keys: Ignored (skipped)
  - Control chars: Ignored
  - Extended chars: Ignored

**Function Flow**:

1. Print prompt: "Enter filename (max 12 chars):"
2. Clear filename buffer
3. Loop to read characters:
   - If Enter pressed: Exit loop
   - If Backspace pressed: Delete last char and update display
   - If valid character and < 12 chars: Store and display it
   - If invalid or special key: Ignore
4. Add null terminator for DOS compatibility
5. Print newline
6. Return

**Screen Feedback**: Characters are echoed to screen as user types; backspace shows proper erase with spaces.

---

### 4. `create_new_file` PROC - Create and edit a new file

```
INPUT:  None
OUTPUT: New file created with user-edited content
```

**Function Flow**:

1. Call `get_filename` to get filename
2. Validate filename is not empty
3. Initialize variables:
   - `char_count` = 0
   - `cursor_row` = 5 (first editable row)
   - `cursor_col` = 0
4. Clear screen
5. Make cursor visible with BIOS
6. Set cursor to top-left (row 0, col 0)
7. Print help text: "Press CTRL+S to save, ESC to exit"
8. Position cursor to (row 5, col 0) - start of editing area
9. Initialize SI register to point to `edit_buffer`
10. **Main editing loop** (see section below)

**Editing Loop (edit_loop)**:

- Wait for keypress with BIOS int 16h (returns AH=scan code, AL=ASCII)
- Process keys:
  - **ESC (scan code 01h)**: Exit editing, return to menu
  - **CTRL+S (AL=13h)**: Save file
  - **Backspace (scan code 0Eh)**: Delete character/previous line
  - **Enter (AL=13)**: Create new line
  - **Arrow keys**: All disabled (no-op, just return to loop)
  - **Regular characters**: Add to buffer and display

**Character Input Handler**:

1. Check if buffer full (2000 chars max)
2. If full: Skip character
3. If not full:
   - Display character on screen
   - Store in buffer at SI
   - Increment SI pointer
   - Increment char_count
   - Increment cursor_col
   - If cursor_col reaches 80 (end of line): Wrap to next line
     - Reset cursor_col to 0
     - Increment cursor_row
     - Set cursor position

**Enter Key Handler**:

1. Print newline on screen (CR+LF)
2. Store CR (13) in buffer
3. Store LF (10) in buffer
4. Increment char_count by 2
5. Reset cursor_col to 0
6. Increment cursor_row
7. Set cursor position
8. Return to edit loop

**Backspace Handler**:

1. Check if buffer is empty (char_count = 0)
2. Check if cursor at beginning of line (cursor_col = 0)

**Case 1: Not at line beginning**:

- Decrement SI pointer
- Mark buffer position as '$' (clear)
- Decrement char_count
- Decrement cursor_col
- Erase character on screen:
  - Send backspace (ASCII 8)
  - Send space to cover character
  - Send backspace to reposition cursor

**Case 2: At line beginning (previous line backspace)**:

1. Check if at first editable row (row 5) - if yes, can't go back
2. Decrement SI pointer (point to LF)
3. Clear LF character ('$')
4. Decrement char_count
5. Decrement SI pointer (point to CR)
6. Verify it's CR (ASCII 13) - if not CR, don't clear
7. Clear CR character ('$')
8. Decrement char_count
9. Now SI points to last char of previous line
10. Count characters on that line backwards to find actual line start:
    - Use DI register to scan backwards from SI
    - Count characters until finding LF or buffer start
    - This count becomes new cursor_col
11. Decrement cursor_row
12. Set cursor to new position
13. Return to edit loop

**Save Handler**:

1. Use DOS int 21h function 3Ch to create file (overwrites if exists)
   - CX=0 for normal file attributes
   - DX = offset to filename
2. Check carry flag for error
3. If error (CF=1): Jump to save_error
4. If success:
   - Store file handle in file_handle variable
5. Use DOS int 21h function 40h to write to file:
   - BX = file handle
   - CX = char_count (bytes to write)
   - DX = offset to edit_buffer
6. Use DOS int 21h function 3Eh to close file:
   - BX = file handle
7. Position cursor at row 23 (status line)
8. Print success message
9. Wait for keypress
10. Return to edit loop

**Error Handling**:

- If file creation fails: Show error message, wait for keypress, return to loop
- If filename empty: Show error message, wait for keypress, return to menu

---

### 5. `load_file` PROC - Load and edit existing file

```
INPUT:  None
OUTPUT: File loaded into buffer, ready for editing
```

**Function Flow**:

**1. Get Filename & Open File**:

- Call `get_filename`
- Use DOS int 21h function 3Dh to open file:
  - AL=0 for read mode
  - DX = offset to filename
- Check carry flag for error
- If error: Jump to load_error
- Store file handle

**2. Read File Content**:

- Use DOS int 21h function 3Fh:
  - BX = file handle
  - CX = 1999 (max bytes to read)
  - DX = offset to edit_buffer
- Return value AX contains bytes read
- Store bytes read in char_count

**3. Close File**:

- Use DOS int 21h function 3Eh:
  - BX = file handle

**4. Prepare Display**:

- Add '$' terminator to buffer for print_string macro (if not full)
- Clear screen
- Position cursor at (0, 0)
- Print help text
- Position cursor at (5, 0)
- Print entire loaded file using `print_string` macro

**5. Position Cursor After Loaded Text**:

- Initialize SI to point to edit_buffer
- Add char_count to SI (now points to end of loaded text)
- Count newlines and calculate correct cursor position:
  - Start at row 5, col 0
  - Scan through entire buffer character by character
  - When finding LF (ASCII 10):
    - Increment cursor_row
    - Reset cursor_col to 0
  - When finding regular character:
    - Increment cursor_col
- After loop, SI points to end and (cursor_row, cursor_col) is correct
- Set cursor position

**6. Editing Loop (edit_loop2)**:

- **Identical to create_new_file's edit_loop** with identical features:
  - Character input
  - Backspace handling
  - Enter key handling
  - CTRL+S save
  - ESC exit
  - Arrow keys disabled

**7. Save Handler (save_file2)**:

- Same as create_new_file but labeled differently
- Creates/overwrites file
- Writes current buffer contents
- Closes file
- Shows success message

**Error Handling**:

- If file doesn't exist or can't open: Show error message, wait for keypress, return to menu
- If file is too large (>1999 bytes): Truncates at 1999 bytes

---

### 6. `MAIN` PROC - Program entry point

```
INPUT:  None (program starts here)
OUTPUT: Program execution
```

**Function Flow**:

1. Initialize data segment:
   - Move segment address of @DATA into DS register
2. Main menu loop:
   - Call `display_menu` to show options
   - Call `get_choice` to get user's selection
   - Check choice:
     - '1': Jump to `do_new_file` section
     - '2': Jump to `do_load_file` section
     - '3': Jump to `exit_program` section
     - Other: Loop back to main menu
3. On invalid input: Continue looping

**do_new_file Section**:

- Call `create_new_file`
- Jump back to main_loop

**do_load_file Section**:

- Call `load_file`
- Jump back to main_loop

**exit_program Section**:

- Clear screen
- Use DOS int 21h function 4Ch to exit program with code 0

---

## Editing Features

### 1. Text Input

- **Type any printable character** to insert at cursor position
- **Auto-wrapping**: When reaching column 80, automatically wraps to next line
- **Buffer limit**: Maximum 2000 characters
- **Real-time echo**: Characters appear on screen immediately

### 2. Backspace/Delete

- **In middle of line**: Delete character before cursor
  - Visual feedback: backspace, space to cover, backspace to reposition
  - Buffer updated correctly
  - Cursor moves back one position
- **At beginning of line**: Join with previous line
  - Removes CR+LF characters
  - Cursor moves to end of previous line
  - Text from previous line end + new text flows together
  - **Fixed in recent update**: Properly calculates column position on previous line

### 3. Enter/New Line

- **Press Enter**: Create new line (CR+LF in buffer)
- **Visual effect**: Line wraps on screen
- **Buffer**: Stores both CR (13) and LF (10)
- **Cursor**: Moves to column 0 of next row

### 4. Arrow Keys

- **All arrow keys DISABLED** (no-op)
  - Up arrow: Does nothing
  - Down arrow: Does nothing
  - Left arrow: Does nothing
  - Right arrow: Does nothing
- **Reason**: Simplified navigation to avoid cursor positioning bugs

### 5. Save Command

- **Press CTRL+S** to save current buffer to file
- **File handling**:
  - Creates new file (overwrites existing)
  - Writes entire buffer (0 to char_count)
  - Closes file properly
- **Feedback**: Success message on screen, wait for keypress
- **Can save multiple times** without exiting editor

### 6. Exit Editing

- **Press ESC** to finish editing and return to main menu
- **Options from main menu**: New file, Load file, or Exit program

---

## File Operations

### Create New File

```
1. Select option "1. Create New File" from menu
2. Enter filename (max 12 characters)
3. Type content in editor
4. Press CTRL+S to save
5. Press ESC to return to menu
```

### Load Existing File

```
1. Select option "2. Load Existing File" from menu
2. Enter filename to load
3. File content displays on screen
4. Cursor positioned at end of file
5. Edit content as needed
6. Press CTRL+S to save changes (overwrites original)
7. Press ESC to return to menu
```

### File Storage

- **Location**: Same directory as program
- **Format**: Plain text (DOS format with CR+LF line endings)
- **Maximum size**: 1999 bytes
- **Filename length**: 1-12 characters

---

## Complete Feature List

### Working Features ✓

1. ✓ Main menu with 3 options
2. ✓ Create new text file
3. ✓ Load existing text file
4. ✓ Full text editing in buffer (2000 chars)
5. ✓ Character input with real-time echo
6. ✓ Backspace to delete characters
7. ✓ Backspace to join lines from previous line
8. ✓ Enter key to create new lines
9. ✓ Line wrapping at 80 columns
10. ✓ CTRL+S to save file
11. ✓ ESC to exit editor
12. ✓ Filename input with validation (12 char max)
13. ✓ Input validation (only printable chars accepted)
14. ✓ File creation and overwrite
15. ✓ File reading (up to 1999 bytes)
16. ✓ File closing
17. ✓ Cursor positioning with BIOS
18. ✓ Screen clearing
19. ✓ Error handling for file operations
20. ✓ Error handling for empty filename
21. ✓ Proper cursor positioning on file load (fixed)
22. ✓ Proper backspace to previous line (fixed)

### Disabled Features

1. ✗ Arrow key navigation (all disabled - no-op)
   - Up arrow: Disabled
   - Down arrow: Disabled
   - Left arrow: Disabled
   - Right arrow: Disabled

### Not Implemented (Future Enhancements)

- Copy/Paste functionality
- Find/Replace
- Undo/Redo
- Line numbering
- Multiple files open simultaneously
- Syntax highlighting
- Text formatting
- Delete key (only Backspace)
- Scroll up/down in editor

---

## Known Limitations & Fixes Applied

### Limitations

1. **Max file size**: 1999 bytes (due to 2000-byte buffer with $ terminator)
2. **Screen size**: Fixed 80x25 (standard DOS)
3. **Filename length**: Maximum 12 characters
4. **No scroll**: Cannot scroll beyond screen (lines 5-24)
5. **Arrow keys disabled**: Navigation only possible by typing/backspace
6. **Single file**: Only one file in memory at a time

### Bugs Fixed in Development (versions 0 to 4.0)

#### Fix #1: Cursor Position on File Load (Versions 1→2)

**Problem**: When loading a file with cursor at end, visual cursor displayed at column 0, but typing overwrote existing text at correct position in file.

**Root Cause**: Cursor position calculation only counted newlines but didn't track column position on the final line.

**Solution**: Modified counting loop to increment cursor_col for each regular character, reset only on newlines.

```assembly
; Before: Only counted newlines
not_newline:
inc di
dec cx
jmp count_newlines

; After: Count characters on each line
not_newline:
inc cursor_col        ; Count chars on current line
next_char:
inc di
dec cx
jmp count_newlines
```

#### Fix #2: Backspace to Previous Line (Versions 2→3)

**Problem**: When backspacing at line beginning to join with previous line, text position in file was incorrect; new typed text went to wrong location.

**Root Cause**: SI pointer wasn't correctly positioned at end of previous line; cursor_col calculation was wrong.

**Solution**:

1. Properly verify and remove CR+LF characters
2. Keep SI pointing to last character of previous line (correct append position)
3. Count characters on previous line backwards to calculate correct cursor_col

```assembly
; Old logic: Tried to move SI forward after finding LF
found_prev_1:
mov si, di          ; Wrong! This is at the LF
inc si              ; Now past the LF, not at last char
dec cursor_col      ; Wrong calculation

; New logic: SI stays at last char before LF
at_start_1:
; Now SI points to the last char of previous line
; Count backwards from SI to find actual line length
```

#### Fix #3: Arrow Keys Disabled (Version 4.0)

**Problem**: Arrow key navigation could cause cursor misalignment and buffer corruption.

**Solution**: Made all arrow key handlers (UP, DOWN, LEFT, RIGHT) no-ops - they simply return to main loop without changing state.

```assembly
; Simple no-op handlers
arrow_up:
    jmp edit_loop

arrow_down:
    jmp edit_loop

arrow_left:
    jmp edit_loop

arrow_right:
    jmp edit_loop
```

---

## Technical Notes

### Memory Layout

```
0x0000 - 0x03FF: PSP (Program Segment Prefix)
0x0400 - DATA:   Data segment variables
0x???? - CODE:   Code segment (procedures)
0xFFFF:          End of 64KB segment
```

### Register Usage

- **DS**: Data segment
- **SI/DI**: Buffer/string pointers
- **AX/AH/AL**: Character and function codes
- **BX**: File handle
- **CX**: Character count, counter
- **DX**: Offset to strings/filenames
- **DH/DL**: Row/Column for cursor

### Interrupt Usage

- **INT 10h**: BIOS video functions (cursor, screen)
- **INT 16h**: BIOS keyboard (raw keypress reading)
- **INT 21h**: DOS functions (file I/O, character I/O, program exit)

### File Naming Convention

- Version numbers represent development stages
- Code3.0.asm: Third major version (baseline)
- Code4.0.asm: Fourth major version (arrow keys disabled)

---

## Program Flow Diagram

```
START
  ↓
Initialize DS
  ↓
MAIN LOOP ─→ Display Menu
             ↓
             Get Choice
             ↓
      ┌──────┴──────┬──────────┐
      ↓             ↓          ↓
    '1'           '2'        '3'
      ↓             ↓          ↓
   NEW FILE    LOAD FILE    EXIT
      ↓             ↓          ↓
  Get Name    Get Name    Clear Screen
      ↓             ↓          ↓
  Edit Loop   Edit Loop   Exit (4Ch)
      ↓             ↓
  ESC → Return to MAIN LOOP
```

---

## Summary

This Mini Text Editor demonstrates fundamental x86-86 assembly programming concepts including:

- Real-mode DOS programming
- BIOS and DOS interrupt usage
- Buffer management and pointer arithmetic
- State machine design (menu + edit loops)
- File I/O operations
- Basic input validation
- Screen and cursor control

The program is fully functional for basic text editing and file operations, with proper error handling and user feedback throughout the interface.

---

**Last Updated**: January 18, 2026  
**Current Version**: Code4.0.asm  
**Status**: Stable (all major bugs fixed)
