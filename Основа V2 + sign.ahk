#SingleInstance Force
LOAD_FAST_CODE()
CONNECTING_TO_GAME("speed.exe", "speed.exe")

ss := FAST_SEARCH_SIGNATURE_IN_PROCESS("44 61 79 4D 6F 6E 64 00")
MsgBox(ss)
ExitApp()


CONNECTING_TO_GAME(NAME_GAME, DLL_GAME)
{
    global PID, Client, ProcessHandle
    if (!PID        := ProcessWait(NAME_GAME, 60))
    {
        MsgBox("Игра не найдена!")
        ExitApp()
    }
    Client          := GET_DLL_BASE(DLL_GAME, PID)
    ProcessHandle   := DllCall("OpenProcess", "int", 2035711, "char", 0, "UInt", PID, "UInt")
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
	space_PATTERN := " " PATTERN
	format_PATTERN := StrReplace(RegExReplace(StrReplace(space_PATTERN, A_Space, " 0x"), A_Space, "", , 1, 1), "0x??", "-1")
	PATTERN := StrSplit(format_PATTERN, A_Space)

	create_array_cpp := Buffer(PATTERN.Length * 1)
	loop PATTERN.Length
	{
		NumPut("Char", PATTERN[A_Index], create_array_cpp.Ptr, (A_Index - 1) * 1)
	}

	bytes := Buffer(END_ADDRESS, 0)
	if (DllCall("Kernel32\ReadProcessMemory", "UInt", ProcessHandle, "UInt", START_ADDRESS, "Ptr", bytes, "Ptr", END_ADDRESS, "UInt", 0))
	{
		result := DllCall(A_PtrSize = 8 ? "Fcode64\add" : "Fcode32\add", "Ptr", bytes, "UInt", END_ADDRESS, "Ptr", create_array_cpp, "Int", PATTERN.Length)
		if (result != -100)
		{
			return Format("0x{:02X}", START_ADDRESS + result + EXTRA)
		}
		else
		{
			return -100
		}
	}
}

FAST_SEARCH_SIGNATURE_IN_PROCESS(PATTERN := "", EXTRA := 0)
{
	static MEM_COMMIT := 0x1000
	static MEM_FREE := 0x10000
	static MEM_RESERVE := 0x2000
	
	_MEMORY_BASIC_INFORMATION := Buffer(A_PtrSize = 8 ? 48 : 28, 0)

	old_RegionSize := 0
	RegionSize := 0

	loop
	{
		if (DllCall("VirtualQueryEx", "Ptr", ProcessHandle, "Ptr", old_RegionSize += RegionSize, "Ptr", _MEMORY_BASIC_INFORMATION, "Ptr", _MEMORY_BASIC_INFORMATION.Size))
		{
			;BaseAddress := Format("0x{:02X}", NumGet(_MEMORY_BASIC_INFORMATION, 0, "Int64"))
			AllocationBase := Format("0x{:02X}", NumGet(_MEMORY_BASIC_INFORMATION, 8, "Int64"))
			RegionSize := Format("0x{:02X}", NumGet(_MEMORY_BASIC_INFORMATION, 24, "Int64"))
			State := Format("0x{:02X}", NumGet(_MEMORY_BASIC_INFORMATION, 32, "UInt"))

			if (State == MEM_COMMIT)
			{
				result := FAST_SEARCH_SIGNATURE_IN_MODULE(PATTERN, EXTRA, AllocationBase, RegionSize)
				if (result != -100 and result != "")
				{
					return result
				}
			}
		}
	}
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

READ_MEMORY(ADDRESS, TYPE := "UInt")
{
	if (DllCall("Kernel32\ReadProcessMemory", "UInt", ProcessHandle, "UInt", ADDRESS, TYPE "*", &uint32 := 0, "Ptr", 16, "UInt", 0))
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