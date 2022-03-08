.386
.model flat, stdcall
option casemap : none
include msvcrt.inc
includelib msvcrt.lib
INCLUDELIB kernel32.lib;这个库用于调用Win32的ExitProcess API函数.
INCLUDELIB ucrt.lib;这个库里面有C函数的实现.
INCLUDELIB legacy_stdio_definitions.lib;这个库里面有C函数的声明,不包含这个库链接时会出错，跟VS版本有关(VS2017必须包含).
scanf proto c:dword,:vararg
printf proto c:dword,:vararg
strlen proto c:dword,:vararg
endl equ <0DH,0AH>
.data
;numcharA/B最多容纳100个字节的字符，全部初始化为0
numCharA byte 100 dup(0)
numCharB byte 100 dup(0)
resultChar byte 200 dup(0)
numIntA dword 100 dup(0)
numIntB dword 100 dup(0)
result dword 200 dup(0)
;输入的格式
inputMsg byte "please input the number: ",endl,0
input byte "%s", 0
;输出的格式
outputMsg byte "the result is %s",endl,0
outputMsg2 byte "the result is %s%s",endl,0
;把lenthA/B/C初始化为0
lengthA dword 0
lengthB dword 0
lengthC dword 0
Symbol dword 0
;符号标志位，初始值为0，表示为正，为1表示为负    
radix dword 10
negativeFlag byte 0
negativeImg byte "-"
szPause db 'pause',0
.code


reverse proc far C numChar:ptr byte,numInt:ptr dword,len:dword
	;esi=numChar首地址
    mov esi,numChar
    ;eax=esi[0]
	movzx eax,byte ptr[esi]
	;Symbol=eax，判断numChar第一个字符是否为负号
	mov Symbol,eax
	.if Symbol==2DH
        ;为负数，negativeFlag异或1
		xor negativeFlag,1
        ;调用strlen得到numChar的长度
		invoke strlen,numChar
        ;减去负号
		sub eax,1
		mov len,eax
		mov ecx,len
        ;esi=numChar[1]
		inc esi
		L1:
            ;eax=esi[i]
			movzx eax,byte ptr[esi]
            ;减去'0',得到数字0-9
			sub eax,30H
            ;压栈
			push eax
            ;esi=numChar[i+1]
			inc esi
			loop L1
        ;重置循环次数
		mov ecx,len
        ;esi=numInt[0]
		mov esi,numInt
		L2:
            ;从栈中弹出数据，依次存储到numInt中，达到反序的目的
			pop eax
			mov dword ptr[esi],eax
            ;esi+4，因为numInt为dword数组，4个偏移量为一个数据
			add esi,4
			loop L2
        ;再次调用strlen，使eax=len，返回时从eax即可读出len的值
		invoke strlen,numChar
		sub eax,1
	.else
		invoke strlen,numChar
		mov len,eax
		mov ecx,len
		L3:
			;eax=esi[i]
			movzx eax,byte ptr[esi]
            ;减去'0',得到数字0-9
			sub eax,30H
            ;压栈
			push eax
            ;esi=numChar[i+1]
			inc esi
			loop L3
		mov ecx,len
		mov esi,numInt
		L4:
			;从栈中弹出数据，依次存储到numInt中，达到反序的目的
			pop eax
			mov dword ptr[esi],eax
            ;esi+4，因为numInt为dword数组，4个偏移量为一个数据
			add esi,4
			loop L4
        ;再次调用strlen，使eax=len，返回时从eax即可读出len的值
		invoke strlen,numChar
	.endif
	ret
reverse endp
int2str_reverse proc far C uses eax esi ecx 
    mov ecx, lengthC ;结果的长度为循环的次数
    mov esi, 0 
L1:
    mov eax, dword ptr result[4 * esi] 
    add eax, 30H ;数字0~9 + '0'得到字符'0'~'9'
    push eax
    inc esi
    loop L1 ;把dword数组numInt全部入栈，最高位先入栈，最低位最后入栈

    mov ecx, lengthC
    mov esi, 0
L2:
    pop eax
    mov byte ptr resultChar[esi], al ;依次出栈，把低八位存在resultChar的对应位置中，最低位先出栈，存在resultChar的最低位中
    inc esi
    loop L2

    ret
int2str_reverse endp
high_multiply proc far C uses eax ecx esi ebx
    mov ebx, -1
OuterLoop: 
    inc ebx
    cmp ebx, lengthA
    jnb endLoop1 ;如果ebx >= lengthA,结束循环
    xor ecx, ecx
InnerLoop:
    xor edx, edx
    mov eax, dword ptr numIntA[4 * ebx]
    mul numIntB[4 * ecx] ;numIntA[4 * ebx] * numIntB[4 * ecx]结果放在EDX:EAX中,最大9*9 = 81也不会超过8个字节，所以结果只在EAX中
    mov esi, ecx
    add esi, ebx ;esi = ecx + ebx，即两个下标之和
    add result[4 * esi], eax ;把两个位相乘的结果加到result的相应位上
    inc ecx
    cmp ecx, lengthB 
    jnb OuterLoop ;无符号数ecx>=lengthB时，下标超过lengthB - 1时跳出内层循环重新进行外层循环
    jmp InnerLoop   ;不超过则继续进行内层循环
endLoop1:
    mov ecx, lengthA
    add ecx, lengthB
    inc ecx ;ecx = lengthA + lengthB + 1
    mov esi, offset lengthC
    mov [esi], ecx ;将ecx赋给lengthC

    xor ebx, ebx
CarryCul:
    cmp ebx, ecx
    jnb endLoop2 ;ebx >= ecx跳到endLoop2,跳出求进位的循环
    mov eax, result[4  * ebx]
    xor edx, edx
    div radix
    add result[4 * ebx + 4], eax ;result[i+1] += result[i]/10
    mov result[4 * ebx], edx ;result[i] = result[i] % 10
    inc ebx
    jmp CarryCul
endLoop2: 
    mov ecx, lengthC ;让MoveZero从最后一位开始检查
MoveZero:
    cmp dword ptr result[4 * ecx], 0
    jnz endwhile1 ;result的末位不为0
    dec ecx ;每检测到一个0，实际长度减一 
    jmp MoveZero
endwhile1:
    inc ecx ;实际长度为最大下标加一
    mov esi, offset lengthC
    mov [esi], ecx ;将ecx赋给lengthC
    invoke int2str_reverse ;将dword数组逆序并转化为byte数组

    ret
high_multiply endp
;======================================================================================
;主函数
main proc
    ;键盘分别输入A和B，并存储为byte数组
    invoke printf, offset inputMsg
    invoke scanf,addr input,addr numCharA
    invoke printf,offset inputMsg
    invoke scanf,addr input,addr numCharB

	invoke reverse,addr numCharA,addr numIntA,lengthA
	mov lengthA,eax
	invoke reverse,addr numCharB,addr numIntB,lengthB
	mov lengthB,eax

	invoke high_multiply


    .if negativeFlag == 1
        invoke printf, addr outputMsg2,addr negativeImg, addr resultChar
    .else 
        invoke printf, addr outputMsg, addr resultChar
    .endif
	invoke crt_system,addr szPause
    ret
main endp
end main