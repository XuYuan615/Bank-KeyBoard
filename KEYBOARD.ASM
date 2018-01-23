IO3 EQU 30h
IO8 EQU 80h
IO7 EQU 70h
IO5 EQU 50h
ESC_key EQU 0AH
Enter_key EQU 0BH
Backspace_key EQU 0CH

code	segment 'code' ;定义代码段
	assume cs:code,ds:code


keycode db 0H	;键值
keyn db 11h	;键号（在键值表中的位置）

pre_key db 11H	;键前态
post_key db 11H	;键后态
stu_key db 0

dbuf db 15H, 15H, 15H, 15H, 15H, 15H;6 dup(10h)     ;对应segdata数组中的数码管显示值
secret db 14H
count dw 0
Tlabel db 0
pre_time db 0
FLAG db 0FFH,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH,0FFH,1,2,3
is_begin db 1
ps db 0
inputpasskey db ?,?,?
passkeyword db 71H,34H,52H

has_num db 0
password db 09H, 01H, 01H, 02H, 00H, 08H


;键值表 
;keytable db 7EH,7DH,7BH,77H,0BEH,0BDH,0BBH,0B7H,0DEH,0DDH,0DBH,0D7H,0EEH,0EDH,0EBH,0E7H,0FFH;一共16个键
keytable db 0EDH,7EH,7DH,7BH,0BEH,0BDH,0BBH,0DEH,0DDH,0DBH,0EEH,0EBH,0E7H,77H,0B7H,0D7H,0FFH;0~9,esc,enter,backspace,待用,待用,待用,无键

;字段表                                        9                           16     P         N         E           H     中间小横线-   C         L
segdata db 3fh,06h,5bh,4fh,66h,6dh,7dh,07h,7fh,6fh,77h,7ch,39h,5eh,79h,71h,00h,01110011B,00110111B,01111001B,01110110B, 01000000B, 00111001B, 00111000B

main proc far
start:	
	mov ax,code		;建立DS段地址
	mov ds,ax
	call init 		;初始化
L:	call re_key		;读取键盘状态	
	call key_number	        ;判断按键是否按下
	call keyprs0_9	        ;读取按键按下的值
	call keyenter	
	call keyesc
	call keybacksp
	call starttiming
	call overtime
	call display	        ;显示dbuf数组的值
	jmp L
	ret
main endp

;显示OPEN
display_open proc             ;将dbuf设置open字形的字段码
	mov dbuf[0], 12H
	mov dbuf[1], 13H
	mov dbuf[2], 11H
	mov dbuf[3], 00H
	mov dbuf[4], 10H
	mov dbuf[5], 10H
	ret
display_open endp


;显示NO
display_no proc                ;将dbuf设置no字形的字段码
	mov dbuf[0], 00H
	mov dbuf[1], 12H
	mov dbuf[2], 10H
	mov dbuf[3], 10H
	mov dbuf[4], 10H
	mov dbuf[5], 10H
	ret
display_no endp

;密码校验
check_password proc
	push ax
	push cx
	mov si, 6
	mov ax, 0
next_value:
	mov cl, dbuf[si-1]             	;从后往前依次比较
	cmp password[si-1], cl          ;只要有一个错误则直接结束比较
	jnz password_error
	dec si                          ;控制循环变量
	jnz next_value
	call display_open               ;密码正确
password_error: 			;密码错误
	call display_no
	jmp check_over                  ;t

check_over:
	pop cx
	pop ax
	ret
check_password endp

init proc                ;对8255A, 8253A, 74LS373初始化
	mov al,10000001B ;8255A控制字
   	mov dx,IO3+6     ;8255A控制端口
    	out dx,al	 ;送控制字到控制口
	mov al,00110110b ;8253A定时器控制字
	mov dx,IO7+6     ;8253A定时器控制口
	out dx,al        ;送控制字到控制口
	mov ax,1000      ;
	mov dx,IO7       ;定时器0
	out dx,al	 ;送低位值
	mov al,ah        ;高位赋值给低位
	out dx,al        ;送高位值
	mov al,01110110b ;8253A定时器控制字
	mov dx,IO7+6     ;8253A定时器控制口
	out dx,al        ;送控制字到控制口
	mov ax,1000       
	mov dx,IO7+2     ;定时器1（同上）
	out dx,al
	mov al,ah
	out dx,al
	mov dx,IO8       ;选中IO8端口（74LS373）
	mov al,00h       ;设置控制字，不启动计数
	out dx,al        ;给74LS373 D0~D7赋值，只用到D7
	mov pre_key,11H  ;按键的前态
	mov post_key,11H ;按键的后态
	mov ps,0
	mov Tlabel,0
	mov count,10
	mov has_num, 0
	ret
init endp

re_key proc		;读取键盘状态
	push ax
	push bx
	push cx
	push dx   
    	mov al,10000001B
    	mov dx,IO3+6    ;8255A控制口
    	out dx,al	;送控制字到控制口
	mov dx,IO3+4	;8255A的PC口
	mov al,00	;高四位送0
	out dx,al
	in al,dx	;读低四位状态	
	and al,0fH	;只取低四位状态
	cmp al,0fH	
	jz nokey	;如果为0表示没有按键
	call delay5	;否则消除按键抖动
	in al,dx	;再读取低4位的状态	  ？
	mov bl,al	;
	and bl,0fH	;取低四位的值
	mov al,10001000B;
	mov dx,IO3+6    ;8255A控制口
	out dx,al	;
	mov dx,IO3+4	;8255A的PB口
	mov al,00	;低四位送0
	out dx,al
	in al,dx	
	and al,0f0H     ;读取高位的值
	cmp al,0f0H     ;判断高位是否有键按下
	jz nokey	;出错重头来
	add bl,al	;获取键值
	mov al,bl	
	jmp Kbl
nokey:
	mov bl,0FFH	;对应10H无键值状态，11H错误键值状态
Kbl:	
	mov keycode,bl 	;保存键值
	mov bx,0
	mov ch,11h
	mov al,keycode
Ckey: 
	cmp al,keytable[bx]  ;取得KeyCode在KeyTable中的下标值（BX）
	jz keypro            ;循环判断键值是否再数组中
	inc bx               ;存在则记录下表，反之为错误键值
	dec ch
	jnz Ckey
keypro:	
	mov keyn,bl          ;保存当前状态，也是数组下标
	pop dx
	pop cx
	pop bx
	pop ax
	ret
re_key endp
		
key_number proc		
	push ax
	push cx
	push bx
	mov al,keyn
	cmp al,11h
	je npro 	;非单独按键不处理
	mov al,post_key
	mov pre_key,al
	mov al,keyn
	mov post_key,al
	mov al,pre_key
	cmp al,10H
	je Lpost1
	cmp al,post_key
	je Lpost2
	cmp al,10H
	je Lpost4
	jmp npro
Lpost4:mov stu_key,4	;按键放手
	jmp knexit
Lpost1:mov al,post_key
	cmp al,10H
	je Lpost3
	mov stu_key,1	;有键按下
	jmp knexit
Lpost2:mov stu_key,2	;持续按键
	jmp knexit
Lpost3:	
npro:	mov stu_key,0	;无键按下	
knexit:	pop bx
	pop cx
	pop ax
	ret
key_number endp 		
	
clear_buf proc                 ;清空dbuf数组（赋值10H），再OPEN界面输入数据后，立刻清空OPEN显示数据
	push bx
	mov bx, 6
begin_clear:
	mov dbuf[bx-1],10H      ;bx从6开始避免最后一位没有清空
	dec bx
	jnz begin_clear
	mov is_begin, 0
	mov has_num, 0          ;已输入数字数清0
	pop bx
	RET
clear_buf ENDP



;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;v1.0 数字键输入功能
keyprs0_9 proc	        ;处理输入值
	push ax
	mov al,stu_key     ;1->有按键，0->无按键
	cmp al,1
	jne k4             ;无按键
	cmp is_begin, 1    ;有按键，判断是否为初始状态
	jz clear           ;初始状态清空OPEN
	jmp conn           ;跳转数字识别
clear:
	call clear_buf     ;清空显示/数组
conn:
	mov al,post_key    ;当前按键的下标
	cmp al,9       
	jbe in09           ; AL <= 9，为数组字则继续
	jmp kexit          ; AL > 9,非数字则跳转退出
in09:
	mov stu_key,0      ;置为无键状态，反之重复识别输入
	mov si,5

	;定时器处理，有按键状态，变量重置
	mov ax, IO8
	mov al, 10000000B
	out dx, al
	mov dx, IO5
	in al, dx
	and al, 01H
	mov pre_time, al
	mov count, 10
	mov ps, 1           ;设置为有按键状态

	;放置在定时器后，即使输入位数达到6位，依旧重置CD
	cmp has_num,6       ;判断输入数字数量是否为6
	jz kexit            ;达到6位则不再处理后续输入
	inc has_num         ;小于6位继续处理

inloop:
	mov al,dbuf[si-1]   ;数组右移，显示左移，两者相反
	mov dbuf[si],al     ;赋值
	dec si		    ;循环控制
	jnz inloop          
	mov al,post_key     ;获取刚输入值的下标
	mov dbuf,al         ;数组第一位赋值为刚输入的值，即为显示数码管的最后一位
	jmp kexit
k4:
kexit:
	pop ax
	ret
keyprs0_9 endp

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
starttiming proc
	push ax
	push dx
	mov al, ps     ;ps=1 按键按下， ps=0 无按键按下
	cmp al, 1
	jne time_count ;有按键在判断是否是数字
        cmp keyn,9       
	jbe sexit        ;<=9  
	
time_count:
	mov dx, IO5    ;74LS224
	in al, dx
	and al, 01H    ;取最低位
	;mov al, 0
	cmp al, pre_time    ;pre_time 上一个out1的值，相同无法判断，直接退出
	je sexit
	cmp al, 1	    ;不同的情况下，上升沿or下降沿
	je sexit
	dec count           ;满足一秒计数减一
	jnz sexit
	mov Tlabel, 1       ;标记为超时状态  
sexit:
	mov pre_time, al
	pop dx
	pop ax
	ret
starttiming endp

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
overtime proc			;判断是否处于超时状态
	push ax
	mov al, ps              ;是否多余，在starttiming中已经判断是否有按键按下，以及超时状态的设置，该函数应该对超时的判断处理
	cmp al, 1
	jne oexit
	mov al, Tlabel		;取超时标志位
	cmp al, 1               ;1为超时状态，0为还未到达超时状态
	jne oexit
	mov dbuf, 16            ;超时则清空数码管
	mov dbuf[0], 10H
	mov dbuf[1], 10H
	mov dbuf[2], 10H
	mov dbuf[3], 10H
	mov dbuf[4], 10H
	mov dbuf[5], 10H
	mov dx, IO8             ;超时状态复位重置
	out dx, al
	mov count, 10
	mov Tlabel, 0
	mov ps, 0
	mov has_num, 0
oexit:
	pop ax
	ret
overtime endp
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;v1.0 Esc功能
keyesc proc
	push ax
	mov al,stu_key    	;1->有按键，0->无按键
	cmp al,1              
	jne noesc             	;无按键			   	
	cmp keyn, 0AH           ;有按键，判断是否为Esc键
	jne noesc               ;不是Esc键则退出
	call clear_buf          ;是Esc键则清空dbuf数组
noesc:	
	pop ax
	ret
keyesc endp
	
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

keyenter proc
	push ax
	mov al,stu_key    	;1->有按键，0->无按键
	cmp al,1              
	jne noenter
	cmp keyn, 0BH
	jne noenter
	call check_password   
noenter:
	pop ax
	ret
keyenter endp

;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;v1.0 Backspace功能
keybacksp proc
	push ax			;push bx出错
	mov al,stu_key    	;1->有按键，0->无按键
	cmp al,1
	jne noesc             	;无按键状态			   	
	cmp keyn, 0CH           ;有键状态，判断是否是Backspace键
	jne nobackspace         ;不是Backspace跳转
	cmp has_num, 0		;是Backspace判断是否还有数字
	jz nobackspace          ;没有数字则退出操作
	mov bx, 0               ;循环初值
back:
	mov ah, dbuf[bx+1]      ;取dbuf的x+1位置的数
	mov dbuf[bx],ah         ;赋值给dbuf的x位置的数
	inc bx			;数组从右往左推，数码管显示为从左往右推
	mov al, bl      
	cmp al, has_num         ;根据数字个数判断循环次数
	jnz back                ;循环结束
	
	mov dbuf[bx-1], 10H     ;最后一位状态为灭
	dec has_num          	;输入数字数减一
nobackspace:
	pop ax
	ret
keybacksp endp

display proc			;显示dbuf数组中的值
	push ax
	push bx
	push cx
	push dx
	push si
	mov cl,6   ;6
	mov ch,11111110B
	mov si,0
J1:	mov al,ch
	rol ch,1	
	mov dx,io3+2
	out dx,al	
	mov al,dbuf[si]
	mov bx,offset segdata
	xlat
    	mov dx,IO3
	out dx,al
	call delay10
	mov al,00H  ;消窜显
	out dx, al
	inc si
	dec cl
	jnz J1
	pop si
	pop dx
	pop cx
	pop bx
	pop ax
	ret
display endp

delay5 proc
	push cx
	mov cx,302
	loop $
	pop cx
	ret
delay5 endp        

delay10 proc
	push cx
	mov cx,200
	loop $
	pop cx
	ret
delay10 endp



code	ends	;代码段结束
	end start