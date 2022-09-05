CONNECTING_TO_GAME()
{
	global
	While True
	{
		Process, Exist, hl2.exe
		PID := ErrorLevel
		if (PID != 0)
		{
			Client := GET_DLL_BASE(Dll_or_EXE, PID)
			PROCESS_HANDLE(PID)
			return False
		}
		sleep 1000
		if (A_Index == 60)
		{
			MsgBox "Игра не найдена!`nПроверь переменную - Dll_or_EXE"
			ExitApp
		}
	}
}

GET_DLL_BASE(Dll, PID)
{
	static TH32CS_SNAPMODULE   := 0x00000008
	static TH32CS_SNAPMODULE32 := 0x00000010
	
	if (PID)
	{
		if (hSnapshot := DllCall("CreateToolhelp32Snapshot", "UInt", (TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32), "UInt", PID, "Ptr"))
		{
			VarSetCapacity(MODULEENTRY32, A_PtrSize = 8 ? 568 : 548, 0)
			NumPut(A_PtrSize = 8 ? 568 : 548, &MODULEENTRY32, 0, "UInt")
			if (DllCall("Module32First", "Ptr", hSnapshot, "Ptr", &MODULEENTRY32))
			{
				while (DllCall("Module32Next", "Ptr", hSnapshot, "Ptr", &MODULEENTRY32))
				{
					if (Dll == StrGet(&MODULEENTRY32 + (A_PtrSize = 8 ? 48 : 32), 256, "CP0"))
					{
						modBaseAddr := NumGet(&MODULEENTRY32, (A_PtrSize = 8 ? 24 : 20), "Ptr")
						global modBaseSize := NumGet(&MODULEENTRY32, (A_PtrSize = 8 ? 32 : 24), "Ptr")
						global hModule := NumGet(&MODULEENTRY32, (A_PtrSize = 8 ? 40 : 24), "Ptr")
						global szModule := StrGet(&MODULEENTRY32 + (A_PtrSize = 8 ? 48 : 32), 256, "CP0")
					}
				}
			}
			DllCall("CloseHandle", "Ptr", hSnapshot)
			return modBaseAddr
		}
	}
}

PROCESS_HANDLE(PID)
{
	global ProcessHandle := DllCall("OpenProcess", "int", 2035711, "char", 0, "UInt", PID, "UInt")
}

READ_MEMORY(address, Type := "Uint")
{
	global ProcessHandle
    if (DllCall("ReadProcessMemory", "UInt", ProcessHandle, "UInt", address, Type "*", value, "Ptr", 4, "UInt", 0))
	{
		return value
	}
}

WRITE_MEMORY(address, value)
{
	global ProcessHandle
	return DllCall("WriteProcessMemory", "UInt", ProcessHandle, "UInt", address, "UInt*", value, "Ptr", 4, "UInt", 0)
}
