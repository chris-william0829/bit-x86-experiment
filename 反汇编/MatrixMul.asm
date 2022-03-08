
.386
.model flat,stdcall
 
include msvcrt.inc
includelib msvcrt.lib
INCLUDELIB kernel32.lib;这个库用于调用Win32的ExitProcess API函数.
INCLUDELIB ucrt.lib;这个库里面有C函数的实现.
INCLUDELIB legacy_stdio_definitions.lib;这个库里面有C函数的声明,不包含这个库链接时会出错，跟VS版本有关(VS2017必须包含).
printf proto c:dword,:vararg


 .data
Result dword 100 dup(0)
MatrixA dword 20 dup(1,2,3,4,5,6,7,8,9,23,24,46,68,23,45,66,32,65,45,24)
MatrixB dword 20 dup(23,45,23,12,43,2,5,6,43,24,12,45,33,22,64,55,23,45,24,23)
output byte "%d ",0
endl byte " ",0AH,0
szPause db 'pause',0
.code
main Proc
;声明局部变量i，j，k
	local i,j,k
;i=0
	mov i,0
;无条件跳转L2，原因是第一次不需要增加后再判断
	jmp L2
;L1为i++
L1:
	mov eax,i
	add eax,1
	mov i,eax
;L2为比较i是否大于等于10，大于等于跳转
L2:
	cmp i,10
	jge L10
;L3为将令j=0，且无条件跳转L5，同i
L3:
	mov j,0
	jmp L5
;L4为j++
L4:
	mov eax,j
	add eax,1
	mov j,eax
;L5为比较j是否大于等于10，大于等于跳转到i++
L5:
	cmp j,10
	jge	L1
;L6为令k=0，无条件跳转L8，同i
L6:
	mov k,0
	jmp L8
;L7为k++
L7:
	mov eax,k
	add eax,1
	mov k,eax
;L8为比较k是否大于等于2，大于等于跳转到j++
L8:
	cmp k,2
	jge L4
L9:
;eax=i*40，因为是dword数组，所以4个偏移量代表一个数据，i*40代表Result的第i行开始的地址
	imul eax,i,40
;将第i行Result的开始地址赋给ecx
	lea ecx,dword ptr Result[eax]
;edx=i*8，表示MatrixA的第i行
	imul edx,i,8
;将MatrixA第i行的起始地址赋给eax
	lea eax,dword ptr MatrixA[edx]
;edx=k*40，表示MatrixB的第k行数据
	imul edx,k,40
;将MatrixB第k行的起始地址赋给edx
	lea edx,dword ptr MatrixB[edx]
;esi=k
	mov esi,k
;edi=j
	mov edi,j
;eax=MatrixA[i][k]，比例变址寻址
	mov eax,dword ptr[eax+esi*4]
;eax=eax*MatrixB[k][j]
	imul eax,dword ptr[edx+edi*4]
;edx=j
	mov edx,j
;eax=eax+Result[i][j]
	add eax,dword ptr[ecx+edx*4]
;Result[i][j]=eax
	mov dword ptr[ecx+edx*4],eax
;最内层循环结束，跳转k++
	jmp L7

;L10为令i=0，并且无条件跳转到判断处
L10:
	mov i,0
	jmp L12
;L11为输出换行并且i++
L11:
	invoke printf,offset endl
	mov eax,i
	add eax,1
	mov i,eax
;L12为比较i是否大于等于10，大于等于跳转到循环结束处
L12:
	cmp i,10
	jge L17
;L13为令j=0，并且无条件跳转到判断
L13:
	mov j,0
	jmp L15
;L14为j++
L14:
	mov eax,j
	add eax,1
	mov j,eax
;L15为比较j是否大于等于10，大于等于则循环结束，跳转到外层i++
L15:
	cmp j,10
	jge	L11
L16:
;eax=i*40，表示Result第i行数据
	imul eax,i,40
;将Result第i行起始地址赋给ecx
	lea ecx,dword ptr Result[eax]
;edx=j
	mov edx,j
;ebx=Result[i][j]
	mov ebx,dword ptr[ecx+edx*4]
;调用输出函数，输出Result[i][j]
	invoke printf,addr output,ebx
;一次循环结束，跳转j++
	jmp L14
;L17为return 0并且返回
L17:
	invoke crt_system,addr szPause
	xor eax,eax
	ret
main endp
end main