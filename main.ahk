#Include classMemory.ahk

#NoEnv
#Persistent
#InstallKeybdHook
#SingleInstance, Force
DetectHiddenWindows, On
SetKeyDelay,-1, -1
SetControlDelay, -1
SetMouseDelay, -1
SendMode Input
SetBatchLines,-1
ListLines, Off

if !Read_csgo_offsets_from_hazedumper() {
	MsgBox, 48, Error, Failed to get csgo offsets!
    ExitApp
}
if (_ClassMemory.__Class != "_ClassMemory") {
    msgbox class memory not correctly installed. Or the (global class) variable "_ClassMemory" has been overwritten
    ExitApp
}

Global m_aimPunchAngle
Global m_dwBoneMatrix
Global m_iHealth
Global m_iTeamNum
Global m_vecOrigin
Global m_vecViewOffset
Global dwClientState
Global dwClientState_MaxPlayer
Global dwClientState_State
Global dwClientState_ViewAngles
Global dwEntityList
Global dwLocalPlayer
Global dwViewMatrix

Process, Wait, csgo.exe
Global csgo := new _ClassMemory("ahk_exe csgo.exe", "", hProcessCopy)
Global client := csgo.getModuleBaseAddress("client.dll")
Global engine := csgo.getModuleBaseAddress("engine.dll")

DllCall("QueryPerformanceFrequency", "Int64*", freq)

GoSub, settings_gui ;GUI

Loop {
	DllCall("QueryPerformanceCounter", "Int64*", LoopBefore)
	IsInGame := IsInGame()
	Global LocalPlayer := GetLocalPlayer()
	Global LocalHealth := csgo.read(LocalPlayer + m_iHealth, "Uint")
	if (IsInGame && LocalPlayer) {
		
		MaxPlayer := GetMaxPlayer()
		
		csgo.readRaw(client + dwEntityList, EntityList, (MaxPlayer+1)*0x10)
		Loop % MaxPlayer {	
			Global Entity := csgo.read(client + dwEntityList + A_index*0x10, "int")
			
			if (Entity=0 || Entity=LocalPlayer)
				Continue
				
			EntityTeam := csgo.read(Entity + m_iTeamNum, "Uint")
			LocalTeam := csgo.read(LocalPlayer + m_iTeamNum, "Uint")

			if (LocalTeam != EntityTeam)  {
				
				if (EnableAimbot && GetKeyState(Hotkey, "P") && LocalHealth > 0) {
					Aimbot()
				}
			}
			
		}
		
	} else {
		Sleep 10
	}

	DllCall("QueryPerformanceCounter", "Int64*", LoopAfter)
	LoopTimer := (LoopAfter - LoopBefore) / freq * 1000
}

SetViewAngle(angle) {
    return new Vector([csgo.write(engine + dwClientState, angle.x, "Float", dwClientState_ViewAngles), csgo.write(engine + dwClientState, angle.y, "Float", dwClientState_ViewAngles+0x4), csgo.write(engine + dwClientState, angle.z, "Float", dwClientState_ViewAngles+0x8)])
}

ClampAngle(angle) {
    if (angle.x > 89.0)
	    angle.x := 89.0
    if (angle.x < -89.0)
	    angle.x := -89.0
		
    if (angle.y > 180.0)
	    angle.y := 180.0
    if (angle.y < -180.0)
	    angle.y := -180.0
    angle.z := 0.0
		
    return angle
}   
	
NormalizeAngle(angle) {
    if (angle.x != angle.x or angle.y != angle.y or angle.z != angle.z)
        return False
		
	if (angle.x > 180.0)
	    angle.x -= 360.0
	if (angle.x < -180.0)
	    angle.x += 360.0
	if (angle.y > 180.0)
	    angle.y -= 360.0
	if (angle.y < -180.0)
	    angle.y += 360.0
	   
    return angle
}

CalculateAngle(startpos, endpos, viewangle) {
	distance := new Vector([endpos.x - startpos.x, endpos.y - startpos.y, endpos.z - startpos.z])
    angle := ToAngle(distance)
    return new Vector([angle.x - viewangle.x, angle.y - viewangle.y, angle.z - viewangle.z])
}

ToAngle(delta) {
    return new Vector([atan2(-delta.z, Hypot(delta.x, delta.y)) * (180.0 / 3.141592653589793), atan2(delta.y, delta.x) * (180.0 / 3.141592653589793), 0.0])
}

GetViewAngles() {
	csgo.readRaw(engine + dwClientState, ViewAngles, 0xC, dwClientState_ViewAngles)
	return new Vector([NumGet(ViewAngles, 0x0, "Float"), NumGet(ViewAngles, 0x4, "Float")])
}

GetVecOrigin() {
	csgo.readRaw(LocalPlayer + m_vecOrigin, origin_struct, 0xC)
	return new Vector([NumGet(origin_struct, 0x0, "Float"), NumGet(origin_struct, 0x4, "Float"), NumGet(origin_struct, 0x8, "Float")])
}

GetVecPunchAngles() {
	csgo.readRaw(LocalPlayer + m_aimPunchAngle, PunchAngles, 0xC)
	return new Vector([NumGet(PunchAngles, 0x0, "Float"), NumGet(PunchAngles, 0x4, "Float"), NumGet(PunchAngles, 0x8, "Float")])
}

VecBone(index) {
	return new Vector([csgo.read(Entity + m_dwBoneMatrix, "Float", 0x30*index + 0x0C)
			  	     , csgo.read(Entity + m_dwBoneMatrix, "Float", 0x30*index + 0x1C)
			  		 , csgo.read(Entity + m_dwBoneMatrix, "Float", 0x30*index + 0x2C)])
}

GetVecEyes() {
	csgo.readRaw(LocalPlayer + m_vecOrigin, origin_struct, 0xC)
	csgo.readRaw(LocalPlayer + m_vecViewOffset, view_offsets_struct, 0xC)
	return new Vector([NumGet(origin_struct, 0x0, "Float")+NumGet(view_offsets_struct, 0x0, "Float")
				     , NumGet(origin_struct, 0x4, "Float")+NumGet(view_offsets_struct, 0x4, "Float")
					 , NumGet(origin_struct, 0x8, "Float")+NumGet(view_offsets_struct, 0x8, "Float")])
}

Hypot(x, y) {
	Return Sqrt(x*x + y*y)
}

GetMaxPlayer() {
	Return csgo.read(engine + dwClientState, "Uint", dwClientState_MaxPlayer)
}

GetLocalPlayer() {
	Return csgo.read(client + dwLocalPlayer, "Uint")
}

IsInGame() {
	Return csgo.read(engine + dwClientState, "Uint", dwClientState_State)=6
}

atan2(y, x) {
	static atan2_func := DllCall("GetProcAddress", "Ptr", DllCall("LoadLibrary", "Str", "msvcrt.dll", "Ptr"), "AStr", "atan2", "Ptr")
	return dllcall(atan2_func, "Double", y, "Double", x, "CDECL Double")
}

atan2f(y, x) {
	static atan2f_func := DllCall("GetProcAddress", "Ptr", DllCall("LoadLibrary", "Str", "msvcrt.dll", "Ptr"), "AStr", "atan2f", "Ptr")
	return dllcall(atan2f_func, "float", y, "float", x, "CDECL float")
}

Aimbot() {
					static BestAngle := new Vector([0.0, 0.0, 0.0])
					static BestFOV := 60
					
					LocalOrigin := GetVecOrigin()
                    ViewAngle := GetViewAngles()
                    AimPunch := GetVecPunchAngles()
					LocalEyePos := GetVecEyes()
					BoneMatrix := VecBone(8)
					CurrentViewAngle := new Vector([ ViewAngle.x + AimPunch.x * 2.0, ViewAngle.y + AimPunch.y * 2.0,  ViewAngle.z + AimPunch.z * 2.0])
					Angle := CalculateAngle(LocalEyePos, BoneMatrix, CurrentViewAngle)
					FOV := Hypot(Angle.x, Angle.y)
					FixedAngle := ClampAngle(NormalizeAngle(Angle))
					
					if (FOV < BestFOV)
                        BestFOV := FOV
                        BestAngle := FixedAngle
						
					if (BestAngle.x < FOV and BestAngle.y < FOV and BestAngle.x != 0.0 and BestAngle.y != 0.0)
					    SetViewAngle(new Vector([ViewAngle.x + BestAngle.x, ViewAngle.y + BestAngle.y, ViewAngle.z + BestAngle.z]))	
}

settings_gui:
Gui, Color, 333333, 9370DB
Gui, add, Checkbox, x10 y10 gSave vEnableAimbot cWhite, AIMBOT
Gui, add, Edit, x10 y40 gSave vHotkey cWhite, XButton1
Gui, Show, x500 w400 h300, Aimbot | Settings
GoTo, Save
Return

Save:
Gui, Submit, NoHide
Return


GuiEscape:
GuiClose:
  ExitApp
Return

class Vector {
	__New(array) {
		this.x  := array[1]
		,this.y := array[2]
		,this.z := array[3] = "" ? 0 : array[3]
	}
}

Read_csgo_offsets_from_hazedumper() {
	whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	whr.Open("GET", "https://raw.githubusercontent.com/frk1/hazedumper/master/csgo.toml", true)
	whr.Send()
	whr.WaitForResponse(-1)
	
	CsgoOffsets := whr.ResponseText
	if InStr(CsgoOffsets, "Not Found")
		Return False

	Loop, parse, CsgoOffsets, `n,`r
	{
		item := A_LoopField
		if !InStr(item, "=")
			Continue
		n := 1
		Loop, parse, item, =
		{
			if (n=1) {
				Str = %A_LoopField%
				n += 1
			} Else if (n=2) {
				%Str% := A_LoopField<<0
			}
		}
	}
	whr := ""
	Return True
}