# Mini Text Editor (8086 Assembly)

A full-featured text editor written in 8086 x86 assembly language using Intel syntax. Runs in DOS/emulated environments like emu8086.

## Features

### Working Features

- Main menu with 3 options (New File, Load File, Exit)
- Create new text files
- Load and edit existing text files
- Full text editing in buffer (2000 characters max)
- Character input with real-time echo
- Backspace to delete characters
- Backspace to join lines from previous line
- Enter key to create new lines
- Line wrapping at 80 columns
- CTRL+S to save file
- ESC to exit editor
- Filename input with validation (12 character max)
- Input validation (only printable characters accepted)
- File creation and overwrite
- File reading (up to 1999 bytes)
- File closing
- Cursor positioning with BIOS
- Screen clearing
- Error handling for file operations
- Error handling for empty filename

### Disabled Features

- Arrow key navigation (all disabled to prevent cursor bugs)

### Not Implemented (Future Enhancements)

- Copy/Paste functionality
- Find/Replace
- Undo/Redo
- Line numbering
- Multiple files open simultaneously
- Syntax highlighting
- Text formatting
- Delete key (only Backspace available)
- Scroll up/down in editor

## Quick Start

1. Run the program in emu8086 or any DOS emulator
2. Select an option from the main menu:
   - **1** - Create New File
   - **2** - Load Existing File
   - **3** - Exit

## How to Use

### Creating a New File

1. Select option **1. Create New File** from menu
2. Enter filename (max 12 characters)
3. Type content in editor
4. Press **CTRL+S** to save
5. Press **ESC** to return to menu

### Loading and Editing a File

1. Select option **2. Load Existing File** from menu
2. Enter filename to load
3. File content displays on screen
4. Cursor positioned at end of file
5. Edit content as needed
6. Press **CTRL+S** to save changes (overwrites original)
7. Press **ESC** to return to menu

## Keyboard Shortcuts

| Key            | Action                                |
| -------------- | ------------------------------------- |
| **CTRL+S**     | Save file                             |
| **ESC**        | Exit editor / Return to menu          |
| **Enter**      | Create new line                       |
| **Backspace**  | Delete character / Join previous line |
| **Arrow Keys** | Disabled (no-op)                      |

## Technical Details

### Memory Model

- **Model**: SMALL (64KB code segment, 64KB data segment)
- **Stack**: 256 bytes
- **Buffer Size**: 2000 characters

### Requirements

- DOS environment or emulator (emu8086, DOSBox, etc.)
- 80x25 display (standard DOS)

### File Specifications

- **Location**: Same directory as program
- **Format**: Plain text (DOS format with CR+LF line endings)
- **Maximum size**: 1999 bytes
- **Filename length**: 1-12 characters

## Program Flow

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

## Known Limitations

1. **Max file size**: 1999 bytes (due to 2000-byte buffer with $ terminator)
2. **Screen size**: Fixed 80x25 (standard DOS)
3. **Filename length**: Maximum 12 characters
4. **No scroll**: Cannot scroll beyond screen (lines 5-24)
5. **Arrow keys disabled**: Navigation only possible by typing/backspace
6. **Single file**: Only one file in memory at a time

## Version History

| Version | Description                                |
| ------- | ------------------------------------------ |
| Code4.0 | Arrow keys disabled to prevent cursor bugs |
| Code3.0 | Baseline with backspace fix                |
| Code2.0 | Cursor position on file load fixed         |
| Code1.0 | Initial release                            |

## License

This project is for educational purposes.

---

**Last Updated**: January 18, 2026  
**Current Version**: Code4.0  
**Status**: Stable (all major bugs fixed)
