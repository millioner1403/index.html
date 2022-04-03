range(from, to)
{
	range := []
	if (from < to)
	{
		While (from <= to)
		{
			range.Push(from++)
		}
	}
	else
	{
		While (from >= to)
		{
			range.Push(from--)
		}
	}
	return range
}

GET_DLL_BASE(DllName, PID)
{
	static TH32CS_SNAPMODULE   := 0x00000008
	static TH32CS_SNAPMODULE32 := 0x00000010

	if (ProcessExist(PID))
	{
		if (hSnapshot := DllCall("CreateToolhelp32Snapshot", "UInt", (TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32), "UInt", PID, "Ptr"))
		{
			MODULEENTRY32 := Buffer(A_PtrSize = 8 ? 568 : 548, 0)
			NumPut("UInt", MODULEENTRY32.Size, MODULEENTRY32, 0)
			modBaseAddr := 0
			if (DllCall("Module32First", "Ptr", hSnapshot, "Ptr", MODULEENTRY32))
			{
				while (DllCall("Module32Next", "Ptr", hSnapshot, "Ptr", MODULEENTRY32))
				{
					if (DllName = StrGet(MODULEENTRY32.Ptr + (A_PtrSize = 8 ? 48 : 32), 256, "CP0"))
					{
						modBaseAddr := NumGet(MODULEENTRY32, (A_PtrSize = 8 ? 24 : 20), "Ptr")
					}
				}
			}
			DllCall("CloseHandle", "Ptr", hSnapshot)
			return modBaseAddr
		}
	}
	return False
}

READ_MEMORY(MADDRESS)
{
	if (DllCall('ReadProcessMemory', 'UInt', ProcessHandle, 'UInt', MADDRESS, 'UInt*', &uint32 := 0, 'Ptr', 4, 'UInt', 0))
	{
		return uint32
	}
}

WRITE_MEMORY(adress, value)
{
    return DllCall("WriteProcessMemory", "UInt", ProcessHandle, "UInt", adress, "UInt*", value, "UInt", 4, "UInt *", 0)
}
WRITE_MEMORY_FLOAT(adress, value)
{
	return DllCall("WriteProcessMemory", "UInt", ProcessHandle, "UInt", adress, "float*", value, "Uint", 4, "Uint *", 0)
}
WRITE_MEMORY_BYTE(adress, value)
{
    return DllCall("WriteProcessMemory", "Char", ProcessHandle, "Char", adress, "Char*", value, "Char", 1, "Char", 0)
}
WriteMemoryUChar(adress, value)
{
	return DllCall("WriteProcessMemory", "Ptr", ProcessHandle, "Ptr", adress, "UChar*", value, "Ptr", 1, "Ptr", 0)
}