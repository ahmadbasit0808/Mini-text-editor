.MODEL SMALL
.STACK 100h

.DATA
    ; Menu messages
    menu_title      db '=== MINI TEXT EDITOR ===$'
    menu_new        db '1. Create New File$'
    menu_load       db '2. Load Existing File$'
    menu_exit       db '3. Exit$'
    menu_choice     db 'Enter your choice (1-3): $'
    
    ; File operation messages
    prompt_filename db 'Enter filename (max 12 chars): $'
    prompt_save     db 'Press CTRL+S to save, ESC to exit$'
    msg_saved       db 'File saved successfully!$'
    msg_error       db 'Error: Could not open file!$'
    msg_loaded      db 'File loaded successfully!$'
    
    ; File variables
    filename        db 13 dup(0)      ; filename buffer (12 chars + null)
    file_handle     dw ?              ; file handle
    file_buffer     db 2000 dup('$')  ; buffer to store file content (2000 bytes)
    edit_buffer     db 2000 dup('$')  ; buffer for editing
    
    ; Cursor position
    cursor_row      db 5              ; starting row for editing
    cursor_col      db 0              ; current column
    
    ; Other variables
    choice          db ?              ; menu choice
    char_count      dw 0              ; number of characters in buffer
    
.CODE

; ========== MACROS ==========

; Print a string
print_string MACRO msg
    mov dx, offset msg
    mov ah, 09h
    int 21h
ENDM

; Print newline
print_newline MACRO
    mov dl, 10        ; line feed
    mov ah, 02h
    int 21h
    mov dl, 13        ; carriage return
    mov ah, 02h
    int 21h
ENDM

; Clear screen (emu8086 compatible method)
clear_screen MACRO
    mov ah, 02h       ; set cursor to upper left corner
    mov dh, 0
    mov dl, 0
    mov bh, 0
    int 10h
    mov ah, 0Ah       ; write character at cursor
    mov al, 00h       ; null character (blank)
    mov cx, 2000      ; 80 columns x 25 rows = 2000 characters
    int 10h
ENDM

; Set cursor position
set_cursor MACRO row, col
    mov ah, 02h
    mov dh, row
    mov dl, col
    mov bh, 0
    int 10h
ENDM

; ========== PROCEDURES ==========

; Display main menu
display_menu PROC
    clear_screen
    print_newline
    print_string menu_title
    print_newline
    print_string menu_new
    print_newline
    print_string menu_load
    print_newline
    print_string menu_exit
    print_newline
    print_newline
    print_string menu_choice
    ret
display_menu ENDP

; Get menu choice from user
get_choice PROC
    mov ah, 01h       ; read character
    int 21h
    mov choice, al
    print_newline
    ret
get_choice ENDP

; Get filename from user
get_filename PROC
    print_newline
    print_string prompt_filename
    
    ; Clear filename buffer
    mov di, offset filename
    mov byte ptr [di], 0
    
    ; Read filename using BIOS keyboard (better control)
    mov si, offset filename
    mov cx, 0         ; character counter
    read_filename:
        mov ah, 00h   ; BIOS keyboard - wait for keypress (no auto-echo)
        int 16h
        
        ; AH = scan code, AL = ASCII character
        cmp ah, 1Ch   ; Enter key scan code
        je filename_done
        
        cmp al, 13    ; Enter key ASCII (backup check)
        je filename_done
        
        cmp ah, 0Eh   ; Backspace scan code
        je handle_backspace
        
        ; Ignore arrow keys and other special keys
        cmp ah, 48h   ; Up arrow
        je read_filename
        cmp ah, 50h   ; Down arrow
        je read_filename
        cmp ah, 4Bh   ; Left arrow
        je read_filename
        cmp ah, 4Dh   ; Right arrow
        je read_filename
        
        ; Check if max characters reached
        cmp cx, 12
        jge read_filename  ; Skip if max reached
        
        ; Check if printable character (ASCII 32-126)
        cmp al, 32
        jb read_filename   ; Skip control characters
        cmp al, 126
        ja read_filename   ; Skip extended characters
        
        ; Valid character - store and display
        mov [si], al      ; store character
        inc si
        inc cx
        
        ; Echo character to screen
        mov dl, al
        mov ah, 02h
        int 21h
        
        jmp read_filename
        
    handle_backspace:
        cmp cx, 0         ; Nothing to delete?
        je read_filename
        
        ; Remove character from buffer
        dec si
        mov byte ptr [si], 0
        dec cx
        
        ; Erase character on screen properly
        mov dl, 8         ; backspace
        mov ah, 02h
        int 21h
        mov dl, 32        ; space (erase the character)
        mov ah, 02h
        int 21h
        mov dl, 8         ; backspace again (move cursor back)
        mov ah, 02h
        int 21h
        
        jmp read_filename
        
    filename_done:
        mov byte ptr [si], 0   ; null terminator for DOS
        print_newline
        ret
get_filename ENDP

; Create new file
create_new_file PROC
    call get_filename
    
    ; Check if filename is empty
    mov si, offset filename
    cmp byte ptr [si], 0
    je filename_empty
    
    ; Initialize editor (no need to clear buffer - we'll overwrite as we type)
    mov char_count, 0
    mov cursor_row, 5
    mov cursor_col, 0
    
    clear_screen
    
    ; Make cursor visible
    mov ah, 01h       ; set cursor type
    mov cx, 0607h     ; visible cursor
    int 10h
    
    set_cursor 0, 0
    print_string prompt_save
    set_cursor cursor_row, cursor_col
    
    ; Start editing
    mov si, offset edit_buffer
    edit_loop:
        mov ah, 00h   ; wait for keypress
        int 16h
        
        cmp ah, 01h   ; ESC key?
        je edit_done
        
        cmp al, 13h   ; CTRL+S (save)?
        je save_file
        
        cmp ah, 0Eh   ; Backspace?
        je handle_edit_backspace
        
        cmp al, 13    ; Enter key?
        je handle_enter
        
        ; Arrow keys - UP
        cmp ah, 48h
        je arrow_up
        
        ; Arrow keys - DOWN
        cmp ah, 50h
        je arrow_down
        
        ; Arrow keys - LEFT
        cmp ah, 4Bh
        je arrow_left
        
        ; Arrow keys - RIGHT
        cmp ah, 4Dh
        je arrow_right
        
        ; Regular character
        cmp char_count, 1999  ; buffer full?
        jge edit_loop
        
        mov dl, al
        mov ah, 02h   ; print character
        int 21h
        
        mov [si], al  ; store in buffer
        inc si
        inc char_count
        inc cursor_col
        
        cmp cursor_col, 80    ; end of line?
        jne edit_loop
        mov cursor_col, 0
        inc cursor_row
        set_cursor cursor_row, cursor_col
        jmp edit_loop
        
    arrow_up:
        jmp edit_loop
        
    arrow_down:
        jmp edit_loop
        
    arrow_left:
        jmp edit_loop
        
    check_prev_line_left:
        
    arrow_right:
        jmp edit_loop
        
    check_next_line_right:
        
    handle_enter:
        print_newline
        mov [si], 13  ; carriage return
        inc si
        mov [si], 10  ; line feed
        inc si
        inc char_count
        inc char_count
        mov cursor_col, 0
        inc cursor_row
        set_cursor cursor_row, cursor_col
        jmp edit_loop
        
    handle_edit_backspace:
        cmp char_count, 0
        je edit_loop
        
        ; Check if at beginning of line (column 0)
        cmp cursor_col, 0
        je check_prev_line_1
        
        ; Not at beginning of line - just delete character
        dec si
        mov [si], '$'
        dec char_count
        dec cursor_col
        ; Erase on screen
        mov dl, 8
        mov ah, 02h
        int 21h
        mov dl, 32
        mov ah, 02h
        int 21h
        mov dl, 8
        mov ah, 02h
        int 21h
        jmp edit_loop
        
    check_prev_line_1:
        ; At beginning of line - try to move to previous line
        cmp cursor_row, 5  ; first editable row?
        je edit_loop        ; cannot go back further
        
        ; Remove the newline characters (CR+LF = 13+10)
        dec si              ; point to LF
        mov [si], '$'       ; clear it
        dec char_count
        
        cmp si, offset edit_buffer  ; at start of buffer?
        je at_start_1
        
        dec si              ; point to CR
        cmp byte ptr [si], 13   ; is it carriage return?
        jne at_start_1      ; if not, don't clear
        mov [si], '$'       ; clear it
        dec char_count
        
    at_start_1:
        ; Now SI points to the last char of previous line (or start of buffer)
        ; Count actual characters on this line backwards to find line start
        mov cursor_col, 0
        mov di, si
        
        count_back_1:
            cmp di, offset edit_buffer
            je line_start_found_1
            
            dec di
            cmp byte ptr [di], 10  ; find line feed (LF)
            je line_start_found_1
            
            inc cursor_col     ; count chars on current line
            jmp count_back_1
            
        line_start_found_1:
            ; DI now points to LF of previous line (or before start)
            ; SI points to last char of previous line (correct position for append)
            dec cursor_row
            set_cursor cursor_row, cursor_col
            jmp edit_loop
        
    save_file:
        ; Create file
        mov ah, 3Ch   ; create file
        mov cx, 0     ; normal file
        mov dx, offset filename
        int 21h
        jc save_error
        
        mov file_handle, ax
        
        ; Write to file
        mov ah, 40h   ; write to file
        mov bx, file_handle
        mov cx, char_count
        mov dx, offset edit_buffer
        int 21h
        
        ; Close file
        mov ah, 3Eh   ; close file
        mov bx, file_handle
        int 21h
        
        set_cursor 23, 0
        print_string msg_saved
        mov ah, 00h   ; wait for keypress
        int 16h
        jmp edit_loop
        
    save_error:
        set_cursor 23, 0
        print_string msg_error
        mov ah, 00h
        int 16h
        jmp edit_loop
        
    edit_done:
        ret
        
    filename_empty:
        print_newline
        print_string msg_error
        mov ah, 00h   ; wait for keypress
        int 16h
        ret
create_new_file ENDP

; Load existing file
load_file PROC
    call get_filename
    
    ; Open file for reading
    mov ah, 3Dh       ; open file
    mov al, 0         ; read mode
    mov dx, offset filename
    int 21h
    jc load_error
    
    mov file_handle, ax
    
    ; Read file
    mov ah, 3Fh       ; read file
    mov bx, file_handle
    mov cx, 1999      ; max bytes to read
    mov dx, offset edit_buffer
    int 21h
    
    mov char_count, ax  ; save number of bytes read
    
    ; Close file
    mov ah, 3Eh       ; close file
    mov bx, file_handle
    int 21h
    
    ; Add '$' terminator for print_string (if buffer not full)
    cmp char_count, 1999
    jge skip_terminator
    mov si, offset edit_buffer
    add si, char_count
    mov byte ptr [si], '$'
    skip_terminator:
    
    ; Display file content
    clear_screen
    set_cursor 0, 0
    print_string prompt_save
    set_cursor 5, 0
    print_string edit_buffer
    
    ; Find end of buffer for editing (position SI at end - fast method)
    mov si, offset edit_buffer
    add si, char_count    ; directly add count instead of looping
    
    ; Position cursor after loaded text
    ; Count lines by counting newline characters and track column position
    mov cursor_row, 5
    mov cursor_col, 0
    mov di, offset edit_buffer
    mov cx, char_count
    count_newlines:
        cmp cx, 0
        je lines_done
        cmp byte ptr [di], 10  ; line feed
        jne not_newline
        inc cursor_row
        mov cursor_col, 0
        jmp next_char
        not_newline:
        inc cursor_col
        next_char:
        inc di
        dec cx
        jmp count_newlines
    lines_done:
    set_cursor cursor_row, cursor_col
    
    ; Start editing (same as create_new_file)
    set_cursor cursor_row, cursor_col
    edit_loop2:
        mov ah, 00h   ; wait for keypress
        int 16h
        
        cmp ah, 01h   ; ESC key?
        je edit_done2
        
        cmp al, 13h   ; CTRL+S (save)?
        je save_file2
        
        cmp ah, 0Eh   ; Backspace?
        je handle_edit_backspace2
        
        cmp al, 13    ; Enter key?
        je handle_enter2
        
        ; Arrow keys - UP
        cmp ah, 48h
        je arrow_up2
        
        ; Arrow keys - DOWN
        cmp ah, 50h
        je arrow_down2
        
        ; Arrow keys - LEFT
        cmp ah, 4Bh
        je arrow_left2
        
        ; Arrow keys - RIGHT
        cmp ah, 4Dh
        je arrow_right2
        
        ; Regular character
        cmp char_count, 1999
        jge edit_loop2
        
        mov dl, al
        mov ah, 02h
        int 21h
        
        mov [si], al
        inc si
        inc char_count
        inc cursor_col
        
        cmp cursor_col, 80
        jne edit_loop2
        mov cursor_col, 0
        inc cursor_row
        set_cursor cursor_row, cursor_col
        jmp edit_loop2
        
    arrow_up2:
        cmp cursor_row, 5
        je edit_loop2
        dec cursor_row
        set_cursor cursor_row, cursor_col
        jmp edit_loop2
        
    arrow_down2:
        jmp edit_loop2
        
    arrow_left2:
        jmp edit_loop2
        
    check_prev_line_left2:
        
    arrow_right2:
        jmp edit_loop2
        
    check_next_line_right2:
        
    handle_enter2:
        print_newline
        mov [si], 13
        inc si
        mov [si], 10
        inc si
        inc char_count
        inc char_count
        mov cursor_col, 0
        inc cursor_row
        set_cursor cursor_row, cursor_col
        jmp edit_loop2
        
    handle_edit_backspace2:
        cmp char_count, 0
        je edit_loop2
        
        ; Check if at beginning of line (column 0)
        cmp cursor_col, 0
        je check_prev_line_2
        
        ; Not at beginning of line - just delete character
        dec si
        mov [si], '$'
        dec char_count
        dec cursor_col
        mov dl, 8
        mov ah, 02h
        int 21h
        mov dl, 32
        mov ah, 02h
        int 21h
        mov dl, 8
        mov ah, 02h
        int 21h
        jmp edit_loop2
        
    check_prev_line_2:
        ; At beginning of line - try to move to previous line
        cmp cursor_row, 5  ; first editable row?
        je edit_loop2       ; cannot go back further
        
        ; Remove the newline characters (CR+LF = 13+10)
        dec si              ; point to LF
        mov [si], '$'       ; clear it
        dec char_count
        
        cmp si, offset edit_buffer  ; at start of buffer?
        je at_start_2
        
        dec si              ; point to CR
        cmp byte ptr [si], 13   ; is it carriage return?
        jne at_start_2      ; if not, don't clear
        mov [si], '$'       ; clear it
        dec char_count
        
    at_start_2:
        ; Now SI points to the last char of previous line (or start of buffer)
        ; Count actual characters on this line backwards to find line start
        mov cursor_col, 0
        mov di, si
        
        count_back_2:
            cmp di, offset edit_buffer
            je line_start_found_2
            
            dec di
            cmp byte ptr [di], 10  ; find line feed (LF)
            je line_start_found_2
            
            inc cursor_col     ; count chars on current line
            jmp count_back_2
            
        line_start_found_2:
            ; DI now points to LF of previous line (or before start)
            ; SI points to last char of previous line (correct position for append)
            dec cursor_row
            set_cursor cursor_row, cursor_col
            jmp edit_loop2
        
    save_file2:
        ; Create/truncate file for writing
        mov ah, 3Ch   ; create file (will overwrite if exists)
        mov cx, 0     ; normal file
        mov dx, offset filename
        int 21h
        jc save_error2
        
        mov file_handle, ax
        
        ; Write to file
        mov ah, 40h   ; write to file
        mov bx, file_handle
        mov cx, char_count
        mov dx, offset edit_buffer
        int 21h
        
        ; Close file
        mov ah, 3Eh   ; close file
        mov bx, file_handle
        int 21h
        
        set_cursor 23, 0
        print_string msg_saved
        mov ah, 00h
        int 16h
        jmp edit_loop2
        
    save_error2:
        set_cursor 23, 0
        print_string msg_error
        mov ah, 00h
        int 16h
        jmp edit_loop2
        
    edit_done2:
        ret
        
    load_error:
        print_newline
        print_string msg_error
        mov ah, 00h   ; wait for keypress
        int 16h
        ret
load_file ENDP

; ========== MAIN PROGRAM ==========
MAIN PROC
    mov ax, @DATA
    mov ds, ax
    
    main_loop:
        call display_menu
        call get_choice
        
        cmp choice, '1'
        je do_new_file
        
        cmp choice, '2'
        je do_load_file
        
        cmp choice, '3'
        je exit_program
        
        ; Invalid choice, loop again
        jmp main_loop
        
    do_new_file:
        call create_new_file
        jmp main_loop
        
    do_load_file:
        call load_file
        jmp main_loop
        
    exit_program:
        clear_screen
        mov ah, 4Ch   ; exit program
        int 21h
        
END MAIN
