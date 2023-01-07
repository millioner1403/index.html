#SingleInstance Force
RUN_AS_ADMINISTRATOR(0)								; 1 = запуск скрипта от имени Администратора | 0 = обычный режим
LOAD_FAST_CODE()									; Подгружает нужные .dll для работы скрипта
CONNECTING_TO_GAME("hl2.exe", "server.dll")			; Первый параметр это процесс игры | Второй параметр это модуль игры (.exe | .dll)



;  		____________________________________________________________________________________________
; 		|																							|
; 		|	  FAST_SEARCH_SIGNATURE_IN_PROCESS - это поиск сигнатуры по всему процессу игры			|
; 		|	  Пример:																				|
; 		|	  address := FAST_SEARCH_SIGNATURE_IN_PROCESS("02 48 ?? 76 A8", 0)						|
; 		|																							|
; 		|	  Функция возвращает адрес																|
; 		|	  Первый параметр 		- наш паттерн													|
; 		|	  Второй параметр 		- смещенние в байтах 											|
; 		|___________________________________________________________________________________________|

;  		____________________________________________________________________________________________
; 		|																							|
; 		|	  FAST_SEARCH_SIGNATURE_IN_MODULE - это поиск сигнатуры внутри указанного модуля игры	|
; 		|	  Пример:																				|
; 		|	  address := FAST_SEARCH_SIGNATURE_IN_MODULE("02 48 ?? 76 A8", 0, 0x620000, 0x10000)	|
; 		|																							|
; 		|	  Функция возвращает адрес																|
; 		|	  Первый параметр 		- наш паттерн													|
; 		|	  Второй параметр 		- смещенние в байтах 											|
; 		|	  Третий параметр 		- начальный адрес модуля в котором хранится наша сигнатура 		|
; 		|	  Четвертый параметр 	- размер модуля который мы указали в третьем параметре			|
; 		|___________________________________________________________________________________________|



CONNECTING_TO_GAME(NAME_GAME, DLL_GAME)
{
    global PID, Client, ProcessHandle
    if (!PID        := ProcessWait(NAME_GAME, 60))
    {
        MsgBox("Игра не найдена!")
        ExitApp()
    }
    Client          := GET_DLL_BASE(DLL_GAME, PID)
    ProcessHandle   := DllCall("OpenProcess", "int", 0x0400 | 0x0010 | 0x0020, "char", 0, "UInt", PID, "UInt")
    return 1
}

GET_DLL_BASE(DLL_GAME, PID)
{
    static TH32CS_SNAPMODULE := 0x00000008
	static TH32CS_SNAPMODULE32 := 0x00000010
    global modBaseSize, hModule

    if (ProcessExist(PID))
    {
        if (hSnapshot := DllCall("CreateToolhelp32Snapshot", "UInt", (TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32), "UInt", PID, "Ptr"))
        {
            MODULEENTRY32 := Buffer(A_PtrSize = 8 ? 568 : 548, 0)
            NumPut("UInt", MODULEENTRY32.Size, MODULEENTRY32, 0)
            if (DllCall("Module32First", "UInt", hSnapshot, "UInt", MODULEENTRY32.Ptr))
            {
                while (DllCall("Module32Next", "UInt", hSnapshot, "UInt", MODULEENTRY32.Ptr))
                {
                    if (DLL_GAME = StrGet(MODULEENTRY32.Ptr + (A_PtrSize = 8 ? 48 : 32), 256, "CP0"))
                    {
                        modBaseAddr := NumGet(MODULEENTRY32, (A_PtrSize = 8 ? 24 : 20), "Ptr")
                        modBaseSize := NumGet(MODULEENTRY32, (A_PtrSize = 8 ? 32 : 24), "Ptr")
                        hModule     := NumGet(MODULEENTRY32, (A_PtrSize = 8 ? 40 : 32), "Ptr")
                    }
                }
            }
            DllCall("CloseHandle", "Ptr", hSnapshot)
            return modBaseAddr
        }
    }
    MsgBox("PID не найден!")
    ExitApp()
}

FAST_SEARCH_SIGNATURE_IN_MODULE(PATTERN := "", EXTRA := 0, START_ADDRESS := Client, END_ADDRESS := modBaseSize)
{
	PATTERN := StrSplit(StrReplace(RegExReplace(StrReplace(" " PATTERN, A_Space, " 0x"), A_Space, "", , 1, 1), "0x??", "-1"), A_Space)
	create_array_cpp := Buffer(PATTERN.Length * 1)

	loop PATTERN.Length
	{
		NumPut("Char", PATTERN[A_Index], create_array_cpp.Ptr, (A_Index - 1) * 1)
	}
	
	result := DllCall(A_PtrSize = 8 ? "Fcode64\module" : "Fcode32\module", "Ptr", ProcessHandle, "Ptr", START_ADDRESS, "Ptr", END_ADDRESS, "Ptr", create_array_cpp, "Int", PATTERN.Length, "Int", EXTRA, "CDecl")
	return result != -100 ? Format("0x{:02X}", result) : result
}

FAST_SEARCH_SIGNATURE_IN_PROCESS(PATTERN := "", EXTRA := 0)
{
	PATTERN := StrSplit(StrReplace(RegExReplace(StrReplace(" " PATTERN, A_Space, " 0x"), A_Space, "", , 1, 1), "0x??", "-1"), A_Space)
	create_array_cpp := Buffer(PATTERN.Length * 1)

	loop PATTERN.Length
	{
		NumPut("Char", PATTERN[A_Index], create_array_cpp.Ptr, (A_Index - 1) * 1)
	}

	result := DllCall(A_PtrSize = 8 ? "Fcode64\process" : "Fcode32\process", "Ptr", ProcessHandle, "Ptr", create_array_cpp, "Int", PATTERN.Length, "Int", EXTRA, "CDecl")
	return result != -100 ? Format("0x{:02X}", result) : result
}

LOAD_FAST_CODE()
{
    #DllLoad "Kernel32.dll"
    #DllLoad "*i Fcode64.dll"
    #DllLoad "*i Fcode32.dll"

	if (!DllCall("GetModuleHandle", "Str", (A_PtrSize = 8 ? "Fcode64.dll" : "Fcode32.dll")))
	{
		MsgBox("Dll: Fcode не обнаружен!")
		ExitApp()
	}
}

RUN_AS_ADMINISTRATOR(KEY := 0)
{
	if (KEY != 0)
	{
		full_command_line := DllCall("GetCommandLine", "str")
		if not (A_IsAdmin or RegExMatch(full_command_line, " /restart(?!\S)"))
		{
			try
			{
				if A_IsCompiled
					Run '*RunAs "' A_ScriptFullPath '" /restart'
				else
					Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
			}
			ExitApp
		}
	}
}

READ_MEMORY(ADDRESS, TYPE := "UInt")
{
	if (DllCall("Kernel32\ReadProcessMemory", "UInt", ProcessHandle, "UInt", ADDRESS, TYPE "*", &uint32 := 0, "Ptr", 4, "UInt", 0))
	{
		return uint32
	}
}

WRITE_MEMORY(ADDRESS, VALUE, TYPE := "UInt")
{
	return DllCall("Kernel32\WriteProcessMemory", "UInt", ProcessHandle, "UInt", ADDRESS, TYPE "*", VALUE, "UInt", 4, "UInt *", 0)
}

INS:: Pause -1
END:: ExitApp
