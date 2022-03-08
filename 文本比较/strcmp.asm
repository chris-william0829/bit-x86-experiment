.386
.model flat,stdcall
option casemap:none

include windows.inc
include gdi32.inc
includelib gdi32.lib
include user32.inc
includelib user32.lib
include kernel32.inc
includelib kernel32.lib
include	msvcrt.inc
includelib msvcrt.lib
include Comdlg32.inc
includelib Comdlg32.lib
include masm32rt.inc
includelib masm32rt.lib

sprintf	PROTO C :ptr sbyte, :ptr sbyte, :VARARG
.data
hInstance dd ?  ;存放应用程序的句柄
hWinMain dd ?   ;存放窗口的句柄
button db 'button',0
szFileName1 db MAX_PATH dup(?)
szFileName2 db MAX_PATH dup(?)
szBuffer1 db 1024 dup(?)
szBuffer2 db 1024 dup(?)

diffNum dword ?
szFilter db 'Text Files(*.txt) ',0,'*.txt',0
		db 'All Files(*.*)',0,'*.*',0,0
szCaption db '执行结果',0
diffOut	byte 2000 dup(0)
.const
endl equ <0DH,0AH>
szClassName db 'MyClass',0
outputMsg byte "the result is %s",endl,0
szCaptionMain db 'CompareFile',0
szText1 db 'Open File1',0
szText2 db 'Open File2',0
szText3 db 'Compare',0
SameContent	db	'there is no different _line between file1 and file2', 0
DiffContent	db	'different line: %d',0AH,0
szBoxTitle	db	'Compare Outcome',0

.code


_ReadLine proc uses ebx,hFile:HANDLE,buffer:ptr byte
	;指向实际读取字节数的指针
	local lpNum:dword
	;用于保存读入数据的一个缓冲区
	local _str:byte
	;ebx=buffer[0]
	mov ebx,buffer
	.while TRUE
		;读入一个1个字符到_str中
		invoke ReadFile,hFile,addr _str,1,addr lpNum,NULL
		;如果指针为空，退出循环
		.break .if !lpNum
		;或者遇到换行号，退出循环
		.break .if _str==10

		;将读入的字符赋给buffer
		mov al,_str
		mov [ebx],al
		;ebx=buffer[i+1]
		inc ebx
	.endw
	;最后一位赋0表示结束
	mov al,0
	mov [ebx],al
	;调用strlen，结果存到eax中，返回eax
	invoke lstrlen,buffer
	ret

_ReadLine endp
_CompareFile proc
	;定义文件句柄
	local hFile1:HANDLE
	local hFile2:HANDLE
	;定义文件指针
	local p1:dword
	local p2:dword
	;定义行数
	local _line:dword
	;用于存储不同的行号
	local diffTem[1000]:byte
	;创建文件句柄
	invoke CreateFile,addr szFileName1,GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
	mov hFile1,eax
	invoke CreateFile,addr szFileName2,GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
	mov hFile2,eax
	
	mov _line,0
	mov diffNum,0

L1:
	inc _line
	;初始化buffer，并读入一行数据
	invoke  RtlZeroMemory,addr szBuffer1,sizeof szBuffer1
	invoke _ReadLine,hFile1,offset szBuffer1
	;返回值为buffer长度
	mov p1,eax
	invoke  RtlZeroMemory,addr szBuffer2,sizeof szBuffer2
	invoke _ReadLine,hFile2,offset szBuffer2
	mov p2,eax

L2:
	;如果长度为0，则表示已读到文件结束
	cmp p1,0
	;不等于0，则跳转L3继续比较p2
	jne L3
	;比较p2长度，如果也为0，表示文件1和2都已读完，结束循环
	cmp p2,0
	je L5

	;若p2不等于0，则表示buffer1为空，buffer2不为空，两者一定不等，记录行号
	invoke sprintf,addr diffTem,offset DiffContent,_line
	invoke lstrcat,addr diffOut,addr diffTem
	;diffNum+1
	inc diffNum
	;继续循环
	jmp L1

L3:
	;比较p2，若不为空则表示p1，p2都不为空，调用strcmp比较
	cmp p2,0
	jne L4
	;若p2为空，则表示buffer1不为空，buffer2为空，两者一定不等，记录行号
	invoke sprintf,addr diffTem,offset DiffContent,_line
	invoke lstrcat,addr diffOut,addr diffTem
	inc diffNum
	jmp L1

L4:
	;调用strcmp比较
	invoke lstrcmp,offset szBuffer1,offset szBuffer2
	cmp eax,0
	;若两者相同，继续循环
	je L1
	;反之记录行号
	invoke sprintf,addr diffTem,offset DiffContent,_line
	invoke lstrcat,addr diffOut,addr diffTem
	inc diffNum
	jmp L1

L5:
	;循环结束，关闭句柄
	invoke CloseHandle,hFile1
	invoke CloseHandle,hFile2
	ret
_CompareFile	ENDP

_OpenFile proc flag:dword
	;定义OPENFILENAME变量
	local @stOF:OPENFILENAME
	;初始化
	invoke RtlZeroMemory,addr @stOF,sizeof @stOF
	mov @stOF.lStructSize,sizeof @stOF
	push hWinMain
	pop @stOF.hwndOwner
	mov @stOF.lpstrFilter,offset szFilter
	;flag标记打开的是文件1还是2
	.if flag==1
		mov @stOF.lpstrFile,offset szFileName1
	.elseif flag==2
		mov @stOF.lpstrFile,offset szFileName2
	.endif
	mov @stOF.nMaxFile,MAX_PATH
	mov @stOF.Flags,OFN_FILEMUSTEXIST OR OFN_PATHMUSTEXIST
	;调用windows对话框打开文件，得到文件路径
	INVOKE GetOpenFileName,addr @stOF
	.if eax == TRUE
		.if flag==1
			invoke MessageBox,hWinMain,addr szFileName1,\
				addr szCaption,MB_OK
		.elseif flag==2
			invoke MessageBox,hWinMain,addr szFileName2,\
				addr szCaption,MB_OK
		.endif

	.endif
	ret

_OpenFile endp

_ProcWinMain proc uses ebx edi esi,hWnd,uMsg,wParam,lParam  ;窗口过程
	local @stPs:PAINTSTRUCT
	local @stRect:RECT
	local @hDc

	mov eax,uMsg  ;uMsg是消息类型，如下面的WM_PAINT,WM_CREATE

	.if eax==WM_PAINT  ;如果想自己绘制客户区，在这里些代码，即第一次打开窗口会显示什么信息
		invoke BeginPaint,hWnd,addr @stPs
		mov @hDc,eax

		invoke EndPaint,hWnd,addr @stPs
	
	.elseif eax==WM_CLOSE  ;窗口关闭消息
		invoke DestroyWindow,hWinMain
		invoke PostQuitMessage,NULL

	.elseif eax==WM_CREATE  ;创建窗口
		invoke CreateWindowEx,NULL,offset button,offset szText1,\
		WS_CHILD or WS_VISIBLE,10,10,200,30,\ 
		hWnd,1,hInstance,NULL  ;1表示该按钮的句柄是1
		invoke CreateWindowEx,NULL,offset button,offset szText2,\
		WS_CHILD or WS_VISIBLE,10,50,200,30,\  
		hWnd,2,hInstance,NULL
		invoke CreateWindowEx,NULL,offset button,offset szText3,\
		WS_CHILD or WS_VISIBLE,10,90,200,30,\ 
		hWnd,3,hInstance,NULL
	.elseif eax==WM_COMMAND  ;点击时候产生的消息是WM_COMMAND
		mov eax,wParam  ;其中参数wParam里存的是句柄，如果点击了一个按钮，则wParam是那个按钮的句柄
		.if eax==1
			invoke _OpenFile,1
		.elseif eax==2
			invoke _OpenFile,2
		.elseif eax==3
			invoke _CompareFile
			;如果没有不同的行号，则输出两个文件相同
			.if diffNum == 0
				invoke MessageBox,hWnd,offset SameContent,offset szBoxTitle,MB_OK+MB_ICONQUESTION
			;反之输出不同的行号
			.else
				invoke MessageBox,hWnd,offset diffOut,offset szBoxTitle,MB_OK+MB_ICONQUESTION
				;初始化diffOut
				invoke RtlZeroMemory,addr diffOut,sizeof diffOut
			.endif
		.endif

	.else  ;否则按默认处理方法处理消息
		invoke DefWindowProc,hWnd,uMsg,wParam,lParam
		ret
	.endif

	xor eax,eax
	ret
_ProcWinMain endp

_WinMain proc  ;窗口程序
	local @stWndClass:WNDCLASSEX  ;定义了一个结构变量，它的类型是WNDCLASSEX，一个窗口类定义了窗口的一些主要属性，图标，光标，背景色等，这些参数不是单个传递，而是封装在WNDCLASSEX中传递的。
	local @stMsg:MSG	;还定义了stMsg，类型是MSG，用来作消息传递的	

	invoke GetModuleHandle,NULL  ;得到应用程序的句柄，把该句柄的值放在hInstance中，句柄是什么？简单点理解就是某个事物的标识，有文件句柄，窗口句柄，可以通过句柄找到对应的事物
	mov hInstance,eax

	invoke RtlZeroMemory,addr @stWndClass,sizeof @stWndClass  ;将stWndClass初始化全0

	;注册窗口类
	invoke LoadCursor,0,IDC_ARROW
	mov @stWndClass.hCursor,eax					;---------------------------------------
	push hInstance
	pop @stWndClass.hInstance
	mov @stWndClass.cbSize,sizeof WNDCLASSEX			;这部分是初始化stWndClass结构中各字段的值，即窗口的各种属性
	mov @stWndClass.style,CS_HREDRAW or CS_VREDRAW			
	mov @stWndClass.lpfnWndProc,offset _ProcWinMain	
	;上面这条语句其实就是指定了该窗口程序的窗口过程是_ProcWinMain
	mov @stWndClass.hbrBackground,COLOR_WINDOW+1
	mov @stWndClass.lpszClassName,offset szClassName		;---------------------------------------
	invoke RegisterClassEx,addr @stWndClass  ;注册窗口类，注册前先填写参数WNDCLASSEX结构

	invoke CreateWindowEx,WS_EX_CLIENTEDGE,\  ;建立窗口
			offset szClassName,offset szCaptionMain,\  ;szClassName和szCaptionMain是在常量段中定义的字符串常量
			WS_OVERLAPPEDWINDOW,100,100,250,180,\	;szClassName是建立窗口使用的类名字符串指针，这里是'MyClass'，表示用'MyClass'类来建立这个窗口，这个窗口拥有'MyClass'的所有属性
			NULL,NULL,hInstance,NULL		;如果改成'button'那么建立的将是一个按钮，szCaptionMain代表的则是窗口的名称，该名称会显示在标题栏中
	mov hWinMain,eax  ;建立窗口后句柄会放在eax中，现在把句柄放在hWinMain中。
	invoke ShowWindow,hWinMain,SW_SHOWNORMAL  ;显示窗口，注意到这个函数传递的参数是窗口的句柄，正如前面所说的，通过句柄可以找到它所标识的事物
	invoke UpdateWindow,hWinMain  ;刷新窗口客户区

	.while TRUE  ;进入无限的消息获取和处理的循环
		invoke GetMessage,addr @stMsg,NULL,0,0  ;从消息队列中取出第一个消息，放在stMsg结构中
		.break .if eax==0  ;如果是退出消息，eax将会置成0，退出循环
		invoke TranslateMessage,addr @stMsg  ;这是把基于键盘扫描码的按键信息转换成对应的ASCII码，如果消息不是通过键盘输入的，这步将跳过
		invoke DispatchMessage,addr @stMsg  ;这条语句的作用是找到该窗口程序的窗口过程，通过该窗口过程来处理消息
	.endw
	ret
_WinMain endp

main proc
	call _WinMain  ;主程序就调用了窗口程序和结束程序两个函数
	invoke ExitProcess,NULL
	ret
main endp
end main
