IDEAL
MODEL small
P186
STACK 100h

DATASEG
    boxSize     db 8

    paletteTable    db 63,0,0, 63,17,0, 63,34,0, 63,51,0, 58,63,0, 21,63,0
                    db 0,63,47, 40,20,5, 0,44,63, 0,27,63, 0,11,63, 6,0,63
                    db 23,0,63, 41,0,63, 58,0,63, 63,0,51, 63,0,34, 63,0,17

    boxX        dw 272,280,288,296,304,312,272,280,288,296,304,312,272,280,288,296,304,312
    boxY        db 0,0,0,0,0,0,8,8,8,8,8,8,16,16,16,16,16,16
    boxColor    db 32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49

    eraserX     dw 4
    eraserY     db 4
    eraserSize  db 16

    clearX      dw 24
    clearY      db 4
    clearSize   db 16

    minusX      dw 44
    minusY      db 4
    minusSize   db 16

    plusX       dw 64
    plusY       db 4
    plusSize    db 16

    brushToolX      dw 192
    brushToolY      db 4
    brushToolSize   db 16

    rectToolX       dw 212
    rectToolY       db 4
    rectToolSize    db 16

    circleToolX     dw 232
    circleToolY     db 4
    circleToolSize  db 16

    triangleToolX       dw 252
    triangleToolY       db 4
    triangleToolSize    db 16

    currentTool     db 0

    px          dw ?
    py          db ?
    pcolor      db ?
    psize       db ?
    rowIndex    db ?
    curY        db ?
    lineLen     db ?

    lineX0      dw 0
    lineX1      dw 319
    lineY       dw 24
    lineColor   db 0

    cursorAndMask   dw 0FFFFh,0FFFFh,0FFFFh,0FFFFh,0FFFFh
                    dw 0FF7Fh,0FF7Fh,0FF7Fh,0F80Fh,0FF7Fh,0FF7Fh,0FF7Fh
                    dw 0FFFFh,0FFFFh,0FFFFh,0FFFFh
    cursorXorMask   dw 16 dup(0)

    brushSize   db 3
    paintX      dw ?
    paintY      db ?
    selectedColor   db 32

    isPainting  db 0
    lastPaintX  dw ?
    lastPaintY  db ?
    strokeCurX  dw ?
    strokeCurY  db ?

    pickHeld    db 0
    brushHalf   db ?

    centerX     dw ?
    centerY     db ?
    sizeParam   db ?

    shapeCenterX    dw ?
    shapeHalfWidth  db ?
    shapeRowY       db ?

    circleRadius    db ?
    circleRadiusSq  dw ?
    circleDy        db ?
    circleDySq      dw ?

    triRow      db ?

    circleBaseX     dw ?
    circleBaseY     db ?

    circleIconOffsets   db 0,4, 4,0, 0,-4, -4,0
                        db 3,2, 3,-2, -3,2, -3,-2
                        db 2,3, 2,-3, -2,3, -2,-3

CODESEG
start:
    mov ax, @data
    mov ds, ax

    mov ah, 0
    mov al, 13h
    int 10h

    call fillBackground
    call loadPalette
    call drawColorBoxes
    call drawEraserIcon
    call drawClearIcon
    call drawMinusIcon
    call drawPlusIcon
    call drawBrushToolIcon
    call drawRectToolIcon
    call drawCircleToolIcon
    call drawTriangleToolIcon
    call updateToolHighlight
    call drawSeparatorLine
    call initMouse

    call paintLoop

    mov ah, 0
    mov al, 3
    int 10h

    mov ax, 4c00h
    int 21h

proc fillBackground
    pusha
    push es

    cld
    mov ax, 0A000h
    mov es, ax
    mov di, 0
    mov al, 15
    mov cx, 320*200
    rep stosb

    pop es
    popa
    ret
endp fillBackground

proc initMouse
    pusha
    push es

    mov ax, 0
    int 33h

    push ds
    pop es
    mov dx, offset cursorAndMask
    mov ax, 9
    mov bx, 8
    mov cx, 8
    int 33h

    mov ax, 1
    int 33h

    pop es
    popa
    ret
endp initMouse

proc paintLoop
    pusha

    paintLoopTop:
        mov ah, 1
        int 16h
        jz noKeyYet
        mov ah, 0
        int 16h
        jmp paintLoopDone

        noKeyYet:
        mov ax, 3
        int 33h
        test bx, 1
        jnz buttonHeld
        mov [isPainting], 0
        mov [pickHeld], 0
        jmp paintLoopTop

        buttonHeld:
        shr cx, 1
        mov [paintX], cx
        mov [paintY], dl

        cmp dl, [byte lineY]
        jbe pickColor

        mov [pickHeld], 0

        mov ax, 2
        int 33h

        cmp [isPainting], 0
        jne alreadyPainting
        mov ax, [paintX]
        mov [lastPaintX], ax
        mov al, [paintY]
        mov [lastPaintY], al
        mov [isPainting], 1

        cmp [currentTool], 0
        je continueStroke
        call paintShape
        jmp toolCallDone

        alreadyPainting:
        cmp [currentTool], 0
        jne toolCallDone

        continueStroke:
        call paintStroke

        toolCallDone:
        mov ax, 1
        int 33h

        jmp paintLoopTop

        pickColor:
        mov [isPainting], 0
        cmp [pickHeld], 0
        jne paintLoopTop
        mov [pickHeld], 1
        call maybeSelectColor
        jmp paintLoopTop

    paintLoopDone:
    popa
    ret
endp paintLoop

proc paintStroke
    pusha

    mov ax, [lastPaintX]
    mov [strokeCurX], ax
    mov al, [lastPaintY]
    mov [strokeCurY], al

    strokeLoop:
        mov ax, [strokeCurX]
        mov [centerX], ax
        mov al, [strokeCurY]
        mov [centerY], al
        mov al, [brushSize]
        mov [sizeParam], al
        call originFromCenter

        mov al, [selectedColor]
        mov [pcolor], al
        mov al, [brushSize]
        mov [psize], al
        call paintBox

        mov ax, [strokeCurX]
        cmp ax, [paintX]
        jne stepX
        mov al, [strokeCurY]
        cmp al, [paintY]
        je strokeDone

        stepX:
        mov ax, [strokeCurX]
        cmp ax, [paintX]
        je sameX
        jb stepXUp
        dec ax
        jmp doneStepX
        stepXUp:
        inc ax
        doneStepX:
        mov [strokeCurX], ax
        sameX:

        mov al, [strokeCurY]
        cmp al, [paintY]
        je sameY
        jb stepYUp
        dec al
        jmp doneStepY
        stepYUp:
        inc al
        doneStepY:
        mov [strokeCurY], al
        sameY:

        jmp strokeLoop

    strokeDone:
    mov ax, [paintX]
    mov [lastPaintX], ax
    mov al, [paintY]
    mov [lastPaintY], al

    popa
    ret
endp paintStroke

proc originFromCenter
    pusha

    mov al, [sizeParam]
    mov ah, 0
    mov bl, 2
    div bl
    mov [brushHalf], al

    mov ax, [centerX]
    mov bl, [brushHalf]
    mov bh, 0
    cmp ax, bx
    jae ofcXNoUnderflow
    mov ax, 0
    jmp ofcXClamped
    ofcXNoUnderflow:
    sub ax, bx
    ofcXClamped:
    mov [px], ax

    mov al, [centerY]
    mov bl, [brushHalf]
    cmp al, bl
    jae ofcYNoUnderflow
    mov al, 0
    jmp ofcYUnderflowDone
    ofcYNoUnderflow:
    sub al, bl
    ofcYUnderflowDone:
    mov bl, [byte lineY]
    inc bl
    cmp al, bl
    jae ofcYClamped
    mov al, bl
    ofcYClamped:
    mov [py], al

    popa
    ret
endp originFromCenter

proc maybeSelectColor
    pusha

    mov ax, [paintX]
    cmp ax, [eraserX]
    jb checkClear
    cmp ax, 20
    jae checkClear

    mov al, [paintY]
    cmp al, [eraserY]
    jb checkClear
    cmp al, 20
    jae checkClear

    mov al, 15
    mov [selectedColor], al
    jmp noSelect

    checkClear:
    mov ax, [paintX]
    cmp ax, [clearX]
    jb checkMinus
    cmp ax, 40
    jae checkMinus

    mov al, [paintY]
    cmp al, [clearY]
    jb checkMinus
    cmp al, 20
    jae checkMinus

    call clearCanvas
    jmp noSelect

    checkMinus:
    mov ax, [paintX]
    cmp ax, [minusX]
    jb checkPlus
    cmp ax, 60
    jae checkPlus

    mov al, [paintY]
    cmp al, [minusY]
    jb checkPlus
    cmp al, 20
    jae checkPlus

    cmp [brushSize], 1
    jne decBrushSize
    jmp noSelect
    decBrushSize:
    dec [brushSize]
    jmp noSelect

    checkPlus:
    mov ax, [paintX]
    cmp ax, [plusX]
    jb checkBrushTool
    cmp ax, 80
    jae checkBrushTool

    mov al, [paintY]
    cmp al, [plusY]
    jb checkBrushTool
    cmp al, 20
    jae checkBrushTool

    cmp [brushSize], 40
    jb incBrushSize
    jmp noSelect
    incBrushSize:
    inc [brushSize]
    jmp noSelect

    checkBrushTool:
    mov ax, [paintX]
    cmp ax, [brushToolX]
    jb checkRectTool
    cmp ax, 208
    jae checkRectTool

    mov al, [paintY]
    cmp al, [brushToolY]
    jb checkRectTool
    cmp al, 20
    jae checkRectTool

    mov [currentTool], 0
    call updateToolHighlight
    jmp noSelect

    checkRectTool:
    mov ax, [paintX]
    cmp ax, [rectToolX]
    jb checkCircleTool
    cmp ax, 228
    jae checkCircleTool

    mov al, [paintY]
    cmp al, [rectToolY]
    jb checkCircleTool
    cmp al, 20
    jae checkCircleTool

    mov [currentTool], 1
    call updateToolHighlight
    jmp noSelect

    checkCircleTool:
    mov ax, [paintX]
    cmp ax, [circleToolX]
    jb checkTriangleTool
    cmp ax, 248
    jae checkTriangleTool

    mov al, [paintY]
    cmp al, [circleToolY]
    jb checkTriangleTool
    cmp al, 20
    jae checkTriangleTool

    mov [currentTool], 2
    call updateToolHighlight
    jmp noSelect

    checkTriangleTool:
    mov ax, [paintX]
    cmp ax, [triangleToolX]
    jb checkGrid
    cmp ax, 268
    jae checkGrid

    mov al, [paintY]
    cmp al, [triangleToolY]
    jb checkGrid
    cmp al, 20
    jae checkGrid

    mov [currentTool], 3
    call updateToolHighlight
    jmp noSelect

    checkGrid:
    mov ax, [paintX]
    cmp ax, 272
    jb noSelect
    cmp ax, 319
    ja noSelect

    cmp [paintY], 24
    jae noSelect

    sub ax, 272
    mov cl, [boxSize]
    div cl
    mov bl, al

    mov al, [paintY]
    mov ah, 0
    div cl

    mov cl, 6
    mul cl
    add al, bl

    mov bh, 0
    mov bl, al
    mov al, [boxColor+bx]
    mov [selectedColor], al

    noSelect:
    popa
    ret
endp maybeSelectColor

proc loadPalette
    pusha
    push es

    push ds
    pop es
    mov dx, offset paletteTable

    mov ah, 10h
    mov al, 12h
    mov bx, 32
    mov cx, 18
    int 10h

    pop es
    popa
    ret
endp loadPalette

proc drawColorBoxes
    pusha

    mov si, 0
    mov di, 0
    drawLoop:
        mov ax, [boxX+di]
        mov [px], ax
        mov al, [boxY+si]
        mov [py], al
        mov al, [boxColor+si]
        mov [pcolor], al
        mov al, [boxSize]
        mov [psize], al

        call paintBox

        inc si
        add di, 2
        cmp si, 18
    jl drawLoop

    popa
    ret
endp drawColorBoxes

proc drawEraserIcon
    pusha

    mov ax, [eraserX]
    mov [px], ax
    mov al, [eraserY]
    mov [py], al
    mov al, 15
    mov [pcolor], al
    mov al, [eraserSize]
    mov [psize], al
    call paintBox

    mov al, 0
    mov [pcolor], al
    call drawIconBorder

    mov ah, 0Ch
    mov bh, 0
    mov dh, 0

    mov al, 4
    mov cx, [eraserX]
    add cx, 1
    mov dl, [eraserY]
    add dl, 1
    mov si, 14
    xDiagDownLoop:
        int 10h
        inc cx
        inc dx
        dec si
    jnz xDiagDownLoop

    mov cx, [eraserX]
    add cx, 14
    mov dl, [eraserY]
    add dl, 1
    mov si, 14
    xDiagUpLoop:
        int 10h
        dec cx
        inc dx
        dec si
    jnz xDiagUpLoop

    popa
    ret
endp drawEraserIcon

proc drawClearIcon
    pusha

    mov ax, [clearX]
    mov [px], ax
    mov al, [clearY]
    mov [py], al
    mov al, 4
    mov [pcolor], al
    mov al, [clearSize]
    mov [psize], al
    call paintBox

    mov al, 0
    mov [pcolor], al
    call drawIconBorder

    mov ah, 0Ch
    mov bh, 0
    mov dh, 0

    mov al, 15
    mov cx, [clearX]
    mov dl, [clearY]
    mov si, 16
    clearXDownLoop:
        int 10h
        inc cx
        inc dx
        dec si
    jnz clearXDownLoop

    mov cx, [clearX]
    add cx, 15
    mov dl, [clearY]
    mov si, 16
    clearXUpLoop:
        int 10h
        dec cx
        inc dx
        dec si
    jnz clearXUpLoop

    popa
    ret
endp drawClearIcon

proc drawMinusIcon
    pusha

    mov ax, [minusX]
    mov [px], ax
    mov al, [minusY]
    mov [py], al
    mov al, 1
    mov [pcolor], al
    mov al, [minusSize]
    mov [psize], al
    call paintBox

    mov al, 0
    mov [pcolor], al
    call drawIconBorder

    mov ah, 0Ch
    mov bh, 0
    mov dh, 0

    mov al, 15
    mov cx, [minusX]
    add cx, 4
    mov dl, [minusY]
    add dl, 7
    mov si, 8
    minusBarLoop:
        int 10h
        inc cx
        dec si
    jnz minusBarLoop

    popa
    ret
endp drawMinusIcon

proc drawPlusIcon
    pusha

    mov ax, [plusX]
    mov [px], ax
    mov al, [plusY]
    mov [py], al
    mov al, 1
    mov [pcolor], al
    mov al, [plusSize]
    mov [psize], al
    call paintBox

    mov al, 0
    mov [pcolor], al
    call drawIconBorder

    mov ah, 0Ch
    mov bh, 0
    mov dh, 0

    mov al, 15
    mov cx, [plusX]
    add cx, 4
    mov dl, [plusY]
    add dl, 7
    mov si, 8
    plusHorizLoop:
        int 10h
        inc cx
        dec si
    jnz plusHorizLoop

    mov cx, [plusX]
    add cx, 7
    mov dl, [plusY]
    add dl, 4
    mov si, 8
    plusVertLoop:
        int 10h
        inc dx
        dec si
    jnz plusVertLoop

    popa
    ret
endp drawPlusIcon

proc drawIconBorder
    pusha

    mov ah, 0Ch
    mov al, [pcolor]
    mov bh, 0
    mov dh, 0

    mov dl, [py]
    mov cx, [px]
    mov bl, [psize]
    mov si, bx
    ibTopLoop:
        int 10h
        inc cx
        dec si
    jnz ibTopLoop

    mov bl, [psize]
    dec bl
    mov dl, [py]
    add dl, bl
    mov cx, [px]
    mov bl, [psize]
    mov si, bx
    ibBottomLoop:
        int 10h
        inc cx
        dec si
    jnz ibBottomLoop

    mov cx, [px]
    mov dl, [py]
    inc dl
    mov bl, [psize]
    sub bl, 2
    mov si, bx
    ibLeftLoop:
        int 10h
        inc dx
        dec si
    jnz ibLeftLoop

    mov bl, [psize]
    dec bl
    mov cx, [px]
    add cx, bx
    mov dl, [py]
    inc dl
    mov bl, [psize]
    sub bl, 2
    mov si, bx
    ibRightLoop:
        int 10h
        inc dx
        dec si
    jnz ibRightLoop

    popa
    ret
endp drawIconBorder

proc drawBrushToolIcon
    pusha

    mov ax, [brushToolX]
    mov [px], ax
    mov al, [brushToolY]
    mov [py], al
    mov al, 15
    mov [pcolor], al
    mov al, [brushToolSize]
    mov [psize], al
    call paintBox

    mov ah, 0Ch
    mov al, 0
    mov bh, 0
    mov dh, 0
    mov cx, [brushToolX]
    add cx, 3
    mov dl, [brushToolY]
    add dl, 3
    mov si, 10
    brushDiagLoop:
        int 10h
        inc cx
        inc dx
        dec si
    jnz brushDiagLoop

    popa
    ret
endp drawBrushToolIcon

proc drawRectToolIcon
    pusha

    mov ax, [rectToolX]
    mov [px], ax
    mov al, [rectToolY]
    mov [py], al
    mov al, 15
    mov [pcolor], al
    mov al, [rectToolSize]
    mov [psize], al
    call paintBox

    mov ax, [rectToolX]
    add ax, 4
    mov [px], ax
    mov al, [rectToolY]
    add al, 4
    mov [py], al
    mov al, 1
    mov [pcolor], al
    mov al, 8
    mov [psize], al
    call drawIconBorder

    popa
    ret
endp drawRectToolIcon

proc drawCircleToolIcon
    pusha

    mov ax, [circleToolX]
    mov [px], ax
    mov al, [circleToolY]
    mov [py], al
    mov al, 15
    mov [pcolor], al
    mov al, [circleToolSize]
    mov [psize], al
    call paintBox

    mov ax, [circleToolX]
    add ax, 8
    mov [circleBaseX], ax
    mov al, [circleToolY]
    add al, 8
    mov [circleBaseY], al

    mov bh, 0
    mov dh, 0
    mov si, offset circleIconOffsets
    mov cx, 12
    circleIconLoop:
        push cx

        mov al, [si]
        cbw
        add ax, [circleBaseX]
        mov cx, ax

        mov al, [circleBaseY]
        add al, [si+1]
        mov dl, al

        mov ah, 0Ch
        mov al, 1
        int 10h

        pop cx
        add si, 2
    loop circleIconLoop

    popa
    ret
endp drawCircleToolIcon

proc drawTriangleToolIcon
    pusha

    mov ax, [triangleToolX]
    mov [px], ax
    mov al, [triangleToolY]
    mov [py], al
    mov al, 15
    mov [pcolor], al
    mov al, [triangleToolSize]
    mov [psize], al
    call paintBox

    mov ah, 0Ch
    mov al, 0
    mov bh, 0
    mov dh, 0

    mov cx, [triangleToolX]
    add cx, 8
    mov dl, [triangleToolY]
    add dl, 2
    mov si, 7
    triLeftEdgeLoop:
        int 10h
        dec cx
        inc dx
        dec si
    jnz triLeftEdgeLoop

    mov cx, [triangleToolX]
    add cx, 8
    mov dl, [triangleToolY]
    add dl, 2
    mov si, 7
    triRightEdgeLoop:
        int 10h
        inc cx
        inc dx
        dec si
    jnz triRightEdgeLoop

    mov cx, [triangleToolX]
    add cx, 2
    mov dl, [triangleToolY]
    add dl, 8
    mov si, 13
    triBaseLoop:
        int 10h
        inc cx
        dec si
    jnz triBaseLoop

    popa
    ret
endp drawTriangleToolIcon

proc updateToolHighlight
    pusha

    mov ax, 2
    int 33h

    mov ax, [brushToolX]
    mov [px], ax
    mov al, [brushToolY]
    mov [py], al
    mov al, 0
    cmp [currentTool], 0
    jne brushBorderColorDone
    mov al, 14
    brushBorderColorDone:
    mov [pcolor], al
    mov al, [brushToolSize]
    mov [psize], al
    call drawIconBorder

    mov ax, [rectToolX]
    mov [px], ax
    mov al, [rectToolY]
    mov [py], al
    mov al, 0
    cmp [currentTool], 1
    jne rectBorderColorDone
    mov al, 14
    rectBorderColorDone:
    mov [pcolor], al
    mov al, [rectToolSize]
    mov [psize], al
    call drawIconBorder

    mov ax, [circleToolX]
    mov [px], ax
    mov al, [circleToolY]
    mov [py], al
    mov al, 0
    cmp [currentTool], 2
    jne circleBorderColorDone
    mov al, 14
    circleBorderColorDone:
    mov [pcolor], al
    mov al, [circleToolSize]
    mov [psize], al
    call drawIconBorder

    mov ax, [triangleToolX]
    mov [px], ax
    mov al, [triangleToolY]
    mov [py], al
    mov al, 0
    cmp [currentTool], 3
    jne triangleBorderColorDone
    mov al, 14
    triangleBorderColorDone:
    mov [pcolor], al
    mov al, [triangleToolSize]
    mov [psize], al
    call drawIconBorder

    mov ax, 1
    int 33h

    popa
    ret
endp updateToolHighlight

proc paintLine
    pusha

    mov ah, 0Ch
    mov al, [pcolor]
    mov bh, 0
    mov dl, [curY]
    mov si, [px]
    mov cl, [lineLen]
    mov ch, 0

    lineLoop:
        push cx
        mov cx, si
        int 10h
        inc si
        pop cx
    loop lineLoop

    popa
    ret
endp paintLine

proc paintBox
    pusha

    mov al, [psize]
    mov [lineLen], al
    mov [rowIndex], 0
    boxRowLoop:
        mov al, [py]
        add al, [rowIndex]
        mov [curY], al

        call paintLine

        inc [rowIndex]
        mov al, [rowIndex]
        cmp al, [psize]
    jl boxRowLoop

    popa
    ret
endp paintBox

proc paintShape
    pusha

    cmp [currentTool], 1
    jne tryCircleShape

    mov ax, [paintX]
    mov [centerX], ax
    mov al, [paintY]
    mov [centerY], al
    mov al, [brushSize]
    mov [sizeParam], al
    call originFromCenter

    mov al, [selectedColor]
    mov [pcolor], al
    mov al, [brushSize]
    mov [psize], al
    call paintBox
    jmp paintShapeDone

    tryCircleShape:
    cmp [currentTool], 2
    jne tryTriangleShape
    call paintCircleShape
    jmp paintShapeDone

    tryTriangleShape:
    cmp [currentTool], 3
    jne paintShapeDone
    call paintTriangleShape

    paintShapeDone:
    popa
    ret
endp paintShape

proc paintCircleShape
    pusha

    mov ax, [paintX]
    mov [shapeCenterX], ax
    mov al, [brushSize]
    mov ah, 0
    mov bl, 2
    div bl
    mov [circleRadius], al

    mov al, [circleRadius]
    mul al
    mov [circleRadiusSq], ax

    mov [circleDy], 0
    circleDyLoop:
        mov al, [circleDy]
        mul al
        mov [circleDySq], ax

        mov [shapeHalfWidth], 0
        circleDxSearch:
            mov al, [shapeHalfWidth]
            inc al
            mul al
            add ax, [circleDySq]
            cmp ax, [circleRadiusSq]
            ja circleDxSearchDone
            inc [shapeHalfWidth]
            mov al, [shapeHalfWidth]
            cmp al, [circleRadius]
        jb circleDxSearch
        circleDxSearchDone:

        mov al, [paintY]
        cmp al, [circleDy]
        jb skipTopRow
        sub al, [circleDy]
        mov bl, [byte lineY]
        inc bl
        cmp al, bl
        jb skipTopRow
        mov [shapeRowY], al
        call drawShapeRow
        skipTopRow:

        cmp [byte circleDy], 0
        je skipBottomRow
        mov al, [paintY]
        add al, [circleDy]
        cmp al, 199
        ja skipBottomRow
        mov bl, [byte lineY]
        inc bl
        cmp al, bl
        jb skipBottomRow
        mov [shapeRowY], al
        call drawShapeRow
        skipBottomRow:

        inc [circleDy]
        mov al, [circleDy]
        cmp al, [circleRadius]
    jbe circleDyLoop

    popa
    ret
endp paintCircleShape

proc paintTriangleShape
    pusha

    cmp [brushSize], 1
    jne triSizeOk
    mov ax, [paintX]
    mov [px], ax
    mov al, [paintY]
    mov [py], al
    mov al, [selectedColor]
    mov [pcolor], al
    mov al, 1
    mov [psize], al
    call paintBox
    jmp triDone

    triSizeOk:
    mov ax, [paintX]
    mov [centerX], ax
    mov al, [paintY]
    mov [centerY], al
    mov al, [brushSize]
    mov [sizeParam], al
    call originFromCenter

    mov al, [brushSize]
    mov ah, 0
    mov bl, 2
    div bl
    mov bh, 0
    mov bl, al
    mov ax, [px]
    add ax, bx
    mov [shapeCenterX], ax

    mov [triRow], 0
    triRowLoop:
        mov al, [triRow]
        mov bl, [brushSize]
        mul bl
        mov bl, [brushSize]
        dec bl
        add bl, bl
        div bl
        mov [shapeHalfWidth], al

        mov al, [py]
        add al, [triRow]
        mov [shapeRowY], al

        call drawShapeRow

        inc [triRow]
        mov al, [triRow]
        cmp al, [brushSize]
    jb triRowLoop

    triDone:
    popa
    ret
endp paintTriangleShape

proc drawShapeRow
    pusha

    mov ax, [shapeCenterX]
    mov bl, [shapeHalfWidth]
    mov bh, 0
    cmp ax, bx
    jae rowXNoUnderflow
    mov ax, 0
    jmp rowXClamped
    rowXNoUnderflow:
    sub ax, bx
    rowXClamped:
    mov [px], ax

    mov al, [shapeHalfWidth]
    mov ah, 0
    shl ax, 1
    inc ax
    mov cx, ax

    mov bx, [px]
    add bx, cx
    dec bx
    cmp bx, 319
    jbe rowLenOk
    mov cx, 319
    sub cx, [px]
    inc cx
    rowLenOk:
    mov al, cl
    mov [lineLen], al

    mov al, [shapeRowY]
    mov [curY], al
    mov al, [selectedColor]
    mov [pcolor], al
    call paintLine

    popa
    ret
endp drawShapeRow

proc drawSeparatorLine
    pusha

    mov ah, 0Ch
    mov al, [lineColor]
    mov bh, 0

    mov dx, [lineY]
    mov cx, [lineX0]
    separatorLoop:
        int 10h
        inc cx
        cmp cx, [lineX1]
    jle separatorLoop

    popa
    ret
endp drawSeparatorLine

proc clearCanvas
    pusha
    push es

    mov ax, 2
    int 33h

    cld
    mov ax, 0A000h
    mov es, ax

    mov ax, [lineY]
    inc ax
    mov bx, 320
    mul bx
    mov di, ax

    mov ax, 199
    sub ax, [lineY]
    mov bx, 320
    mul bx
    mov cx, ax

    mov al, 15
    rep stosb

    pop es

    mov ax, 1
    int 33h

    popa
    ret
endp clearCanvas

END start
