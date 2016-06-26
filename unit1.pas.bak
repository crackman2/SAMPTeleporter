unit Unit1;

{$mode objfpc}{$H+}

interface



uses
  Classes, SysUtils, FileUtil, SynHighlighterCpp, SynEdit, Forms, Controls,
  Graphics, Dialogs, StdCtrls, ExtCtrls, ComCtrls, Buttons, Windows,
  jwatlhelp32, Math, IniFiles;

type
  { TForm1 }

  TForm1 = class(TForm)
    ButtonClearLog: TButton;
    ButtonGetAddresses: TButton;
    ButtonDelLoc: TButton;
    ButtonSaveLoc: TButton;
    ButtonLoadLoc: TButton;
    CheckBoxAmmoLock: TCheckBox;
    CheckBoxHealthLock: TCheckBox;
    CheckBoxAirbrake: TCheckBox;
    CheckBoxAskIfRemove: TCheckBox;
    EditLocName: TEdit;
    ImageMap: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    LabelAirbrakeSpeed: TLabel;
    LabelTelecounter: TLabel;
    LabelPosX: TLabel;
    LabelPosY: TLabel;
    LabelPosZ: TLabel;
    ListBoxDebug: TListBox;
    ListBoxLocations: TListBox;
    Panel1: TPanel;
    TimerAirbrake: TTimer;
    TimerReadPos: TTimer;
    TrackBarAirbrakeSpeed: TTrackBar;
    TrayIcon: TTrayIcon;
    procedure ButtonClearLogClick(Sender: TObject);
    procedure ButtonDelLocClick(Sender: TObject);
    procedure ButtonGetAddressesClick(Sender: TObject);
    procedure ButtonLoadLocClick(Sender: TObject);
    procedure ButtonSaveLocClick(Sender: TObject);
    procedure CheckBoxAirbrakeChange(Sender: TObject);
    procedure CheckBoxAmmoLockChange(Sender: TObject);
    procedure CheckBoxHealthLockChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ImageMapClick(Sender: TObject);
    procedure TimerAirbrakeTimer(Sender: TObject);
    procedure TimerImagePlrTimer(Sender: TObject);
    procedure TimerReadPosTimer(Sender: TObject);
    procedure TrackBarAirbrakeSpeedChange(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

type
  PLAYER = record
    dwAddPosX: DWORD; //Addresses to player coords
    dwAddPosY: DWORD;
    dwAddPosZ: DWORD;
    dwAddCPosX: DWORD;  //Addresses to camera position in world
    dwAddCPosY: DWORD;
    dwAddCPosZ: DWORD;
    fcX: single; //Camera Pos X
    fcY: single; //Camera Pos Y
    fcZ: single;
    fX: single; // Player X
    fY: single;
    fZ: single;
    fAngH: single; //Camera angle , horizontal
    fAngV: single;
  end;

type
  COORDS = record       //struct for saved locations
    fX: single;
    fY: single;
    fZ: single;
    LocationName: string;
  end;


type
  ABCONFIG = record
    jinc: single;    //increment , essentially airbrake speed
    jincnorm: single;  //stores original value
    jincboost: single; //value used when 'boosting' (pressing shitft)
    k: single;
    // = (180/3.14159265358979323); (correction value Rad to Deg or other the way around
    bEnableAirbrake: boolean; //toggles airbrake, changed by hotkey 'x'
    fAbX: single; //new position to be written during airbrake
    fAbY: single;
    fAbZ: single;
  end;


var                             // https://youtu.be/Ws82rXrjBOI
  LocPlayer: PLAYER; //object for local player
  Form1: TForm1;
  hFenster: HWND;   //window handle
  hProcess: HANDLE;  //process handle
  dwProcId: DWORD;   //another unhelpful comment
  dwSAMPBase: DWORD; //base address of "samp.dll", used for calculating addresses
  bGameNotFoundTrigger: boolean = True;
  //confusing thing used for when the game isnt actually running yet
  SavedCoords: array[1..999] of COORDS;
  //a giant array of saved coords which noone ever uses up because you cant save anyway and you've got airbrake... so who cares
  LBIndexer: integer = 0; //Index for the array and also for display in the listbox
  Telecount: integer = 0;
  //counting many times you did not have to travel by conventional means
  PI: single = 3.14159265358979323;  //no idea
  AirBrConf: ABCONFIG; //object for airbrake stuff
  ConfigFile:TIniFile;


implementation

{$R *.lfm}

{ TForm1 }

procedure lbwrite(TXT: string);  //just for debugging and seeming smart
begin
  Form1.ListBoxDebug.ItemIndex := Form1.ListBoxDebug.Items.Add(TXT);
end;


//copy pasted function to find the modules base address
function GetModuleBaseAddress(hProcID: cardinal; lpModName: PChar): Pointer;
var
  hSnap: cardinal;
  tm: TModuleEntry32;
begin
  //result := 0;
  hSnap := CreateToolHelp32Snapshot(TH32CS_SNAPMODULE, hProcID);
  if hSnap <> 0 then
  begin
    tm.dwSize := sizeof(TModuleEntry32);
    if Module32First(hSnap, tm) = True then
    begin
      //while Module32Next(hSnap, tm) = True do
      repeat
        begin
          if lstrcmpi(tm.szModule, lpModName) = 0 then
          begin
            Result := Pointer(tm.modBaseAddr);
            break;
          end;
        end;
      until Module32Next(hSnap, tm) = False;
      //end;
    end;
  end;
  CloseHandle(hSnap);
end;
//end;


//===SIMPLYFIED FUNCTIONS FOR READING AND WRITING N SHIT..====
function ReadDword(Address: DWORD): DWORD;
begin
  ReadProcessMemory(hProcess, Pointer(Address), @Result, sizeof(Result), nil);
end;

function ReadFloat(Address: DWORD): single;
begin
  ReadProcessMemory(hProcess, Pointer(Address), @Result, sizeof(Result), nil);
end;

procedure WriteFloat(Value: single; Address: DWORD);
begin
  WriteProcessMemory(hProcess, Pointer(Address), @Value, sizeof(Value), nil);
end;

procedure WriteByte(Value: byte; Address: DWORD);
begin
  WriteProcessMemory(hProcess, Pointer(Address), @Value, sizeof(byte), nil);
end;
//===END OF SIMPLE SHIT==

//Used because i'm to stupid to associate coodinates to a listbox entry, also copy pasted
function GetIndexFromString(i: integer): integer;
var
  pos1, pos2: integer;
begin
  Result := 0;
  pos1 := Pos('[', Form1.ListBoxLocations.Items[i]);
  pos2 := Pos(']', Form1.ListBoxLocations.Items[i]);
  if (pos1 > 0) and (pos2 > pos1) then
    Result := StrToInt(Copy(Form1.ListBoxLocations.Items[i], pos1 + 1, pos2 - pos1 - 1));
end;


//load location from COORDS array by index, also some flashy output
procedure LoadLoc(LocIndex: integer);
begin
  WriteFloat(SavedCoords[LocIndex].fX, LocPlayer.dwAddPosX);
  WriteFloat(SavedCoords[LocIndex].fY, LocPlayer.dwAddPosY);
  WriteFloat(SavedCoords[LocIndex].fZ, LocPlayer.dwAddPosZ);
  lbwrite('===Teleportet!=== to ' + SavedCoords[LocIndex].LocationName);
  lbwrite('X: ' + floatToStr(SavedCoords[LocIndex].fX));
  lbwrite('Y: ' + floatToStr(SavedCoords[LocIndex].fY));
  lbwrite('Z: ' + floatToStr(SavedCoords[LocIndex].fZ));
  lbwrite('---------');
end;

//initializing addresses
procedure GetAddresses();
begin
  dwSAMPBase := dword(GetModuleBaseAddress(dwProcId, 'samp.dll'));
  LocPlayer.dwAddPosX := ReadDword(dwSAMPBase + $217678) + $30;
  LocPlayer.dwAddPosY := ReadDword(dwSAMPBase + $217678) + $34;
  LocPlayer.dwAddPosZ := ReadDword(dwSAMPBase + $217678) + $38;
  LocPlayer.dwAddCPosX := $400000 + $69AEB4;
  LocPlayer.dwAddCPosY := $400000 + $69AEB8;
  LocPlayer.dwAddCPosZ := $400000 + $76F334; //getAddress("gta_sa.exe")+0x76F334
  lbwrite('Addresses read:');
  lbwrite('"samp.dll" Base: 0x' + inttohex(dwSAMPBase, 8));
  lbwrite('addposx: 0x' + inttohex(LocPlayer.dwAddPosX, 8));
  lbwrite('addposy: 0x' + inttohex(LocPlayer.dwAddPosY, 8));
  lbwrite('addposz: 0x' + inttohex(LocPlayer.dwAddPosZ, 8));
  lbwrite('addcposx: 0x' + inttohex(LocPlayer.dwAddCPosX, 8));
  lbwrite('addcposy: 0x' + inttohex(LocPlayer.dwAddCPosY, 8));
  lbwrite('---------');
end;


//loading location using that horrendous technique
procedure TForm1.ButtonLoadLocClick(Sender: TObject);
var
  i: integer;
  bSelected: boolean = False;
begin
  Inc(Telecount);

  ConfigFile.WriteInteger('Telecount','count',Telecount);


  for i := ListBoxLocations.Items.Count - 1 downto 0 do
  begin
    if ListBoxLocations.Selected[i] then
    begin
      LoadLoc(GetIndexFromString(i));
      bSelected := True;
    end;
  end;
  if bSelected = False then
  begin
    lbwrite('Select a location');
    lbwrite('---------');
  end;
end;






//removes selelected location from list
procedure TForm1.ButtonDelLocClick(Sender: TObject);
var
  i: integer;
  cnt: integer=0;
  bSelected: boolean = False;
begin
  for i := ListBoxLocations.Items.Count - 1 downto 0 do
  begin
    if ListBoxLocations.Selected[i] then
      bSelected := True;
  end;
  if bSelected = False then
  begin
    lbwrite('Select a location');
    lbwrite('---------');
  end
  else
  begin

    if CheckBoxAskIfRemove.Checked then
    begin

      if (messagebox(0, 'Do you really want to delete this location?',
        PChar('Are you sure?'), MB_YESNO) = idYes) then
      begin
        for i := ListBoxLocations.Items.Count - 1 downto 0 do
        begin
          cnt:=0;
          if ListBoxLocations.Selected[i] then begin
            ConfigFile.EraseSection(IntToStr(GetIndexFromString(i)));
            ListBoxLocations.Items.Delete(i);

            while(cnt < ConfigFile.ReadInteger('configconfig','maxindex',1)) do begin
                  if ConfigFile.SectionExists(inttostr(cnt)) then begin
                     LBIndexer:=cnt+1;
                  end;
                  cnt:=cnt + 1;
            end;
            //lbwrite(IntToStr(ListBoxLocations.Items.Count));
            ConfigFile.WriteInteger('configconfig','maxindex',LBIndexer);
            if ListBoxLocations.Items.Count = 0 then begin
              LBIndexer:=0;
              ConfigFile.WriteInteger('configconfig','maxindex',LBIndexer);
            end;

            end;
        end;
        lbwrite('Location deleted.');
        lbwrite('---------');
      end;

    end
    else
    begin
      for i := ListBoxLocations.Items.Count - 1 downto 0 do
      begin
        if ListBoxLocations.Selected[i] then begin
           ConfigFile.EraseSection(IntToStr(GetIndexFromString(i)));
           ListBoxLocations.Items.Delete(i);

           while(cnt < ConfigFile.ReadInteger('configconfig','maxindex',1)) do begin
                  if ConfigFile.SectionExists(inttostr(cnt)) then begin
                     LBIndexer:=cnt+1;
                  end;
                  cnt:=cnt + 1;
            end;
            //lbwrite(IntToStr(LBIndexer));
            ConfigFile.WriteInteger('configconfig','maxindex',LBIndexer);
            if ListBoxLocations.Items.Count = 0 then begin
              LBIndexer:=0;
              ConfigFile.WriteInteger('configconfig','maxindex',LBIndexer);
            end;
        end;
      end;
      lbwrite('Location deleted.');
      lbwrite('---------');
    end;
  end;
end;

//clears log ..
procedure TForm1.ButtonClearLogClick(Sender: TObject);
begin
  ListBoxDebug.Clear;
end;

procedure TForm1.ButtonGetAddressesClick(Sender: TObject);
begin
  ListBoxLocations.Clear;
  hProcess:=0;
  FormCreate(Sender);
end;

//save location, here you can see the awful act of sticking strings together to make the entry
procedure TForm1.ButtonSaveLocClick(Sender: TObject);
var TempIndex:Integer=0;
begin
  if EditLocName.Caption <> '' then begin
  SavedCoords[LBIndexer].fX := LocPlayer.fX;
  SavedCoords[LBIndexer].fY := LocPlayer.fY;
  SavedCoords[LBIndexer].fZ := LocPlayer.fZ;
  SavedCoords[LBIndexer].LocationName := EditLocName.Text;
  lbwrite('Location "' + EditLocName.Text + '"' + ' saved!');
  lbwrite('X: ' + floattostr(SavedCoords[LBIndexer].fX));
  lbwrite('Y: ' + floattostr(SavedCoords[LBIndexer].fY));
  lbwrite('Z: ' + floattostr(SavedCoords[LBIndexer].fZ));
  lbwrite('---------');
  ListBoxLocations.Items.Add('[' + IntToStr(LBIndexer) + ']' + EditLocName.Text);

  ConfigFile.WriteString(IntToStr(LBIndexer),'locname',SavedCoords[LBIndexer].LocationName);
  ConfigFile.WriteString(IntToStr(LBIndexer),'posx',floattostr(SavedCoords[LBIndexer].fX));
  ConfigFile.WriteString(IntToStr(LBIndexer),'posy',floattostr(SavedCoords[LBIndexer].fY));
  ConfigFile.WriteString(IntToStr(LBIndexer),'posz',floattostr(SavedCoords[LBIndexer].fZ));

  TempIndex:=ConfigFile.ReadInteger('configconfig','maxindex',1);
  TempIndex:=TempIndex+1;
  ConfigFile.WriteString('configconfig','maxindex',IntToStr(TempIndex));

  EditLocName.Caption := '';
  Inc(LBIndexer);
  end
  else begin
    lbwrite('Location name must not be empty!');
  end;
end;

//option to enable or disable airbrake hotkey (because airbrake is easily detected)
procedure TForm1.CheckBoxAirbrakeChange(Sender: TObject);
begin
  if CheckBoxAirbrake.Checked then
  begin
    lbwrite('Airbrake-Hotkey enabled! Press X');
    TimerAirbrake.Enabled := True;
  end
  else
  begin
    lbwrite('Airbrake disabled.');
    TimerAirbrake.Enabled := False;
  end;

end;

//NOPs ammo decrement
procedure TForm1.CheckBoxAmmoLockChange(Sender: TObject);
begin
//  gta_sa.exe+3428E6 - FF 4E 0C              - dec [esi+0C]
  if CheckBoxAmmoLock.Checked then
    begin
      WriteByte($90, $400000 + $3428E6);
      WriteByte($90, $400000 + $3428E6 + 1);
      WriteByte($90, $400000 + $3428E6 + 2);
      lbwrite('Infinite Ammo enabled');
    end
    else
    begin
      WriteByte($FF, $400000 + $3428E6);
      WriteByte($4E, $400000 + $3428E6 + 1);
      WriteByte($0C, $400000 + $3428E6 + 2);
      lbwrite('Infinite Ammo disabled');
    end;
end;

//NOPS health decrement (does not disable instant deaths (high falldamage, exploding car while inside etc.)
procedure TForm1.CheckBoxHealthLockChange(Sender: TObject);
begin
  // HP DEC OPCODES: gta_sa.exe+B3314 - D8 65 04              - fsub dword ptr [ebp+04]
  if CheckBoxHealthLock.Checked then
  begin
    WriteByte($90, $400000 + $B3314);
    WriteByte($90, $400000 + $B3314 + 1);
    WriteByte($90, $400000 + $B3314 + 2);
    lbwrite('Invincibility enabled');
  end
  else
  begin
    WriteByte($D8, $400000 + $B3314);
    WriteByte($65, $400000 + $B3314 + 1);
    WriteByte($04, $400000 + $B3314 + 2);
    lbwrite('Invincibility disabled');
  end;
end;

procedure CheckForConfigFile();
var TempIndex:Integer=0;
    MaxIndex:Integer;
begin
       ConfigFile:=TIniFile.Create('SAMPTeleporter.ini');

       if not ConfigFile.SectionExists('configconfig') then begin
         ConfigFile.WriteString('configconfig','maxindex','0');
         ConfigFile.WriteString('Telecount','count','0');
       end;

       MaxIndex:=ConfigFile.ReadInteger('configconfig','maxindex',1);
       //loads all locations from ini into memory, lists them
       while(TempIndex < MaxIndex) do begin
         if ConfigFile.SectionExists(IntToStr(TempIndex)) then begin
           SavedCoords[TempIndex].fX:=ConfigFile.ReadFloat(IntToStr(TempIndex),'posx',1);
           SavedCoords[TempIndex].fY:=ConfigFile.ReadFloat(IntToStr(TempIndex),'posy',1);
           SavedCoords[TempIndex].fZ:=ConfigFile.ReadFloat(IntToStr(TempIndex),'posz',1);
           SavedCoords[TempIndex].LocationName:=ConfigFile.ReadString(IntToStr(TempIndex),'locname','');
           Form1.ListBoxLocations.Items.Add('[' + IntToStr(TempIndex) + ']' + SavedCoords[TempIndex].LocationName);
         end;

         TempIndex:=TempIndex + 1;
       end;

       LBIndexer:=MaxIndex;
end;

//initializatition
procedure TForm1.FormCreate(Sender: TObject);
begin
  //cant check if the trayicon is click while in a while loop. bummer
  TrayIcon.Hint := 'Press "X" to stop waiting and exit SAMP Teleporter';
  while ((hProcess = 0) or (hFenster = 0) or (dwProcId = 0)) do
  begin
    hFenster := FindWindow(nil, 'GTA:SA:MP'); //fidning the game window handle
    GetWindowThreadProcessId(hFenster, @dwProcId);
    //getting the process id from that handle
    hProcess := OpenProcess(PROCESS_ALL_ACCESS, False, dwProcId);
    //get some of dem sweet rights to fool around
    if (hProcess = 0) and bGameNotFoundTrigger then
      //bGameNotFoundTrigger is used to only trigger the messagebox once
    begin
      ShowMessage('Waiting for SA:MP...');
      bGameNotFoundTrigger := False;
      TrayIcon.Visible := True;
      TrayIcon.ShowBalloonHint;
    end;
    if GetAsyncKeyState(VK_X) <> 0 then
      //check if you decided not to cheat for some reason
    begin
      TrayIcon.Hide;
      ExitProcess(0);
    end;
    Sleep(500);
  end;
  TrayIcon.Visible := True;

  lbwrite('Game found.'); //flashy output
  lbwrite('ProcessID: ' + IntToStr(dwProcId));
  lbwrite('hProcess: ' + IntToStr(hProcess));
  GetAddresses();

  //initiliziizng AirBrConf
  AirBrConf.jinc := TrackBarAirbrakeSpeed.Position / 10;
  //trackbar vals get divided by 10 to form float values
  AirBrConf.jincboost := AirBrConf.jinc * 4;  //4 seems like a nice number
  AirBrConf.jincnorm := AirBrConf.jinc;
  AirBrConf.k := (180 / PI); //Rad to Deg or Deg to Rad
  LabelAirbrakeSpeed.Caption := 'Airbrake speed: ' + FloatToStr(AirBrConf.jinc);

  TimerReadPos.Enabled := True;//enable timer to read location

  CheckForConfigFile();

  Telecount:=ConfigFile.ReadInteger('Telecount','count',1);
end;


//teleportation by clicking map (not very accurate, slightly buggy)
procedure TForm1.ImageMapClick(Sender: TObject);
var HeightTitleBar:integer;
    newX:integer;
    newY:integer;
    fnewX:single;
    fnewY:single;
begin
    HeightTitleBar:=GetSystemMetrics(SM_CYCAPTION);
    newX:=(Mouse.CursorPos.X-Form1.Left-ImageMap.Left)-250;
    newY:=-((Mouse.CursorPos.Y-Form1.Top-ImageMap.Top-HeightTitleBar)-250);
    lbwrite('Teleported by map click to:');
    lbwrite('X: ' + inttostr(newX * 12));
    lbwrite('Y: ' + inttostr(newY * 12));
    fnewX:=newX*12;
    fnewY:=newY*12;

    WriteFloat(fnewX,LocPlayer.dwAddPosX);
    WriteFloat(fnewY,LocPlayer.dwAddPosY);
    WriteFloat(-500,LocPlayer.dwAddPosZ);
    inc(Telecount);
    ConfigFile.WriteInteger('Telecount','count',Telecount);
end;


{
    alright so this function is a bit fucky. essentially it looks where the player is and the players camera
    and calculates the angle in relation to the coordinate system.
    also it checks in which quadrant the camera is in relation to the players position
    to properly output an angle (on the horizontal axis) from 0 to 360 degrees
}
function GetAngle(): single;
var
  bIsXPlus: boolean;
  bIsYPlus: boolean;
  fNewPosX: single;
  fNewPosY: single;
  fTempAngH: single;
begin

  if LocPlayer.fcX > LocPlayer.fX then
  begin
    fNewPosX := LocPlayer.fcX - LocPlayer.fX;
    bIsXPlus := True;
  end
  else
  begin
    fNewPosX := LocPlayer.fX - LocPlayer.fcX;
    bIsXPlus := False;
  end;

  if LocPlayer.fcY > LocPlayer.fY then
  begin
    fNewPosY := LocPlayer.fcY - LocPlayer.fY;
    bIsYPlus := True;
  end
  else
  begin
    fNewPosY := LocPlayer.fY - LocPlayer.fcY;
    bIsYPlus := False;
  end;

  fTempAngH := arctan2(fNewPosY, fNewPosX) * (180 / pi);


  if bIsXPlus and bIsYPlus then
    fTempAngH := fTempAngH + 0
  else if (not bIsXPlus) and bIsYPlus then
    fTempAngH := 180 - fTempAngH
  else if (not bIsXPlus) and (not bIsYPlus) then
    fTempAngH := 180 + fTempAngH
  else if (bIsXPlus) and (not bIsYPlus) then
    fTempAngH := 360 - fTempAngH;

  Result := fTempAngH;
  //lbwrite('Angle: ' + FloatToStr(fTempAngH));
  //lbwrite('bIsXPlus: ' + BoolToStr(bIsXPlus));
  //lbwrite('bIsYPlus: ' + BoolToStr(bIsYPlus));
end;


//Airbrake function
procedure TForm1.TimerAirbrakeTimer(Sender: TObject);
begin
  if AirBrConf.bEnableAirbrake then
  begin
    LocPlayer.fcX := ReadFloat(LocPlayer.dwAddCPosX);
    LocPlayer.fcY := ReadFloat(LocPlayer.dwAddCPosY);
    LocPlayer.fcZ := ReadFloat(LocPlayer.dwAddCPosZ);
    LocPlayer.fAngH := GetAngle() / AirBrConf.k;
    LocPlayer.fAngV := (LocPlayer.fcZ*90)/AirBrConf.k;


    if GetAsyncKeyState(VK_W) <> 0 then
    begin
      AirBrConf.fAbX := AirBrConf.fAbX + cos(LocPlayer.fAngH) * (AirBrConf.jinc * cos(LocPlayer.fAngV));
      AirBrConf.fAbY := AirBrConf.fAbY + sin(LocPlayer.fAngH) * (AirBrConf.jinc * cos(LocPlayer.fAngV));
      AirBrConf.fAbZ := AirBrConf.fAbZ + sin(LocPlayer.fAngV) * AirBrConf.jinc;
    end;

    if GetAsyncKeyState(VK_S) <> 0 then
    begin
      AirBrConf.fAbX := AirBrConf.fAbX - cos(LocPlayer.fAngH) * (AirBrConf.jinc * cos(LocPlayer.fAngV));
      AirBrConf.fAbY := AirBrConf.fAbY - sin(LocPlayer.fAngH) * (AirBrConf.jinc * cos(LocPlayer.fAngV));
      AirBrConf.fAbZ := AirBrConf.fAbZ - sin(LocPlayer.fAngV) * AirBrConf.jinc;
    end;

    if GetAsyncKeyState(VK_A) <> 0 then
    begin
      AirBrConf.fAbX := AirBrConf.fAbX - cos(LocPlayer.fAngH - (90 / AirBrConf.k)) *
        (AirBrConf.jinc);
      AirBrConf.fAbY := AirBrConf.fAbY - sin(LocPlayer.fAngH - (90 / AirBrConf.k)) *
        (AirBrConf.jinc);
    end;

    if GetAsyncKeyState(VK_D) <> 0 then
    begin
      AirBrConf.fAbX := AirBrConf.fAbX - cos(LocPlayer.fAngH + (90 / AirBrConf.k)) *
        (AirBrConf.jinc);
      AirBrConf.fAbY := AirBrConf.fAbY - sin(LocPlayer.fAngH + (90 / AirBrConf.k)) *
        (AirBrConf.jinc);
    end;

    if GetAsyncKeyState(VK_SPACE) <> 0 then
    begin
      AirBrConf.fAbZ := AirBrConf.fAbZ + AirBrConf.jinc;
    end;

    if GetAsyncKeyState(VK_LCONTROL) <> 0 then
    begin
      AirBrConf.fAbZ := AirBrConf.fAbZ - AirBrConf.jinc;
    end;

    if GetAsyncKeyState(VK_LSHIFT) <> 0 then
      AirBrConf.jinc := AirBrConf.jincboost
    else
      AirBrConf.jinc := AirBrConf.jincnorm;

    WriteFloat(AirBrConf.fAbX, LocPlayer.dwAddPosX);
    WriteFloat(AirBrConf.fAbY, LocPlayer.dwAddPosY);
    WriteFloat(AirBrConf.fAbZ, LocPlayer.dwAddPosZ);
  end;


  //checking hotkey
  if GetAsyncKeyState(VK_X) <> 0 then
  begin
    if AirBrConf.bEnableAirbrake = False then
    begin
      //on enable it writes the current position
      //into AirBrConf for later manipulation
      AirBrConf.fAbX := ReadFloat(LocPlayer.dwAddPosX);
      AirBrConf.fAbY := ReadFloat(LocPlayer.dwAddPosY);
      AirBrConf.fAbZ := ReadFloat(LocPlayer.dwAddPosZ);

      {
       disable falldamage timer (or whatever its called) (avoids fall damage, avoids death when flying through the ground)
      }
      //gta_sa.exe+148503 - D8 47 08              - fadd dword ptr [edi+08]
      WriteByte($90,$400000 + $148503);
      WriteByte($90,$400000 + $148503 + 1);
      WriteByte($90,$400000 + $148503 + 2);

      AirBrConf.bEnableAirbrake := True;
      //lbwrite('Airbrake on');
      //annoying message, may i should make an option to disable this
    end
    else
    begin
      AirBrConf.bEnableAirbrake := False;
      {
       //THIS WAS THE SHIT WAY. ITS NOT USED ANYMORE
       when disabling airbrake the players position on the z axis is put underground to force a respawn nearby
       this avoid death on landing due to falldamage but also makes it impossible to land accurately on a certain spot
      }
      //WriteFloat(-1000, LocPlayer.dwAddPosZ);
      {
       reenable fall timer
      }
      WriteByte($D8,$400000 + $148503);
      WriteByte($47,$400000 + $148503 + 1);
      WriteByte($08,$400000 + $148503 + 2);
      //lbwrite('Airbrake off');
    end;

    while GetAsyncKeyState(VK_X) <> 0 do
    begin
      //loop aimlessly while the key is still pressed to avoid bugs.
      //you get the idea.. im too lazy to spell it out
      Sleep(50);
    end;
  end;

end;

procedure TForm1.TimerImagePlrTimer(Sender: TObject);
begin
  //if ImagePlr.Visible then ImagePlr.Visible:=false else ImagePlr.Visible:=true;
end;


//read positions, changes labels to output position and teleportation count
procedure TForm1.TimerReadPosTimer(Sender: TObject);
begin
  LocPlayer.fX := ReadFloat(LocPlayer.dwAddPosX);
  LocPlayer.fY := ReadFloat(LocPlayer.dwAddPosY);
  LocPlayer.fZ := ReadFloat(LocPlayer.dwAddPosZ);
  LabelPosX.Caption := FloatToStr(LocPlayer.fX);
  LabelPosY.Caption := FloatToStr(LocPlayer.fY);
  LabelPosZ.Caption := FloatToStr(LocPlayer.fZ);
  LabelTelecounter.Caption := 'Teleportation count: ' + IntToStr(Telecount);
  //player cursor position

  //lbwrite('IMGX: ' + inttostr(ImagePlr.Top));

   //map size (ingame units) 6000x6000
  Panel1.Top := ImageMap.Top + (-((round(LocPlayer.fY) div 12))) + 250 - (Panel1.Height div 2);
  Panel1.Left:= ImageMap.Left+ (round(LocPlayer.fX) div 12) + 250 - (Panel1.Width div 2);


  // SetLayeredWindowAttributes(Panel1.Handle,$FFFF00,$FF0000,1);

end;

//trackbar for changing airbrake speed
procedure TForm1.TrackBarAirbrakeSpeedChange(Sender: TObject);
begin
  AirBrConf.jinc := TrackBarAirbrakeSpeed.Position / 10;
  AirBrConf.jincboost := AirBrConf.jinc * 4;
  AirBrConf.jincnorm := AirBrConf.jinc;
  LabelAirbrakeSpeed.Caption := 'Airbrake speed: ' + FloatToStr(AirBrConf.jinc);
end;

end.
