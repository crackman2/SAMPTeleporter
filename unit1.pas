unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ValEdit, ExtCtrls, Windows, jwatlhelp32;

type

  { TForm1 }

  TForm1 = class(TForm)
    ButtonClearLog: TButton;
    ButtonGetAddresses: TButton;
    ButtonDelLoc: TButton;
    ButtonSaveLoc: TButton;
    ButtonLoadLoc: TButton;
    CheckBoxAirbrake: TCheckBox;
    CheckBoxAskIfRemove: TCheckBox;
    EditLocName: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    LabelTelecounter: TLabel;
    LabelPosX: TLabel;
    LabelPosY: TLabel;
    LabelPosZ: TLabel;
    ListBoxDebug: TListBox;
    ListBoxLocations: TListBox;
    TimerAirbrake: TTimer;
    TimerReadPos: TTimer;
    procedure ButtonClearLogClick(Sender: TObject);
    procedure ButtonDelLocClick(Sender: TObject);
    procedure ButtonGetAddressesClick(Sender: TObject);
    procedure ButtonLoadLocClick(Sender: TObject);
    procedure ButtonSaveLocClick(Sender: TObject);
    procedure CheckBoxAirbrakeChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Label1Click(Sender: TObject);
    procedure LBDebugClick(Sender: TObject);
    procedure ListBoxLocationsClick(Sender: TObject);
    procedure TimerAirbrakeTimer(Sender: TObject);
    procedure TimerReadPosTimer(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

type
  PLAYER = record
    dwAddPosX: DWORD;
    dwAddPosY: DWORD;
    dwAddPosZ: DWORD;
    dwAddCPosX: DWORD;
    dwAddCPosY: DWORD;
    fcX: single;
    fcY: single;
    fX: single;
    fY: single;
    fZ: single;
  end;

type
  COORDS = record
    fX: single;
    fY: single;
    fZ: single;
    LocationName: string;
  end;




type
  ABCONFIG = record
    jinc: single;
    k: single;// = (180/3.14159265358979323);
    bEnableAirbrake: Boolean;
    AbX:SINGLE;
    AbY:SINGLE;
    AbZ:SINGLE;
  end;


var                             // https://youtu.be/Ws82rXrjBOI
  LocPlayer: PLAYER;
  Form1: TForm1;
  hFenster: HWND;
  hProcess: HANDLE;
  dwProcId: DWORD;
  dwSAMPBase: DWORD;
  bGameNotFoundTrigger: boolean = True;
  SavedCoords: array[1..999] of COORDS;
  LBIndexer: integer = 0;
  Telecount: integer = 0;
  AirBrakeLoc: COORDS;
  PI: single = 3.14159265358979323;
  AirBrConf: ABCONFIG;



implementation

{$R *.lfm}

{ TForm1 }

procedure lbwrite(TXT: string);
begin
  Form1.ListBoxDebug.ItemIndex := Form1.ListBoxDebug.Items.Add(TXT);
end;

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



procedure LoadLoc(LocIndex: integer);
begin
  WriteFloat(SavedCoords[LocIndex].fX, LocPlayer.dwAddPosX);
  WriteFloat(SavedCoords[LocIndex].fY, LocPlayer.dwAddPosY);
  WriteFloat(SavedCoords[LocIndex].fZ, LocPlayer.dwAddPosZ);
  lbwrite('===Teleportet!=== to ' + SavedCoords[LocIndex].LocationName);
  lbwrite('X: ' + IntToStr(LocIndex) + floatToStr(SavedCoords[LocIndex].fX));
  lbwrite('Y: ' + IntToStr(LocIndex) + floatToStr(SavedCoords[LocIndex].fY));
  lbwrite('Z: ' + IntToStr(LocIndex) + floatToStr(SavedCoords[LocIndex].fZ));
  lbwrite('---------');
end;




procedure GetAddresses();
begin
  dwSAMPBase := dword(GetModuleBaseAddress(dwProcId, 'samp.dll'));
  LocPlayer.dwAddPosX := ReadDword(dwSAMPBase + $217678) + $30;
  LocPlayer.dwAddPosY := ReadDword(dwSAMPBase + $217678) + $34;
  LocPlayer.dwAddPosZ := ReadDword(dwSAMPBase + $217678) + $38;
  LocPlayer.dwAddCPosX := ReadDword($400000 + $69AEB4);
  LocPlayer.dwAddCPosY := ReadDword($400000 + $69AEB8);
  lbwrite('Addresses read:');
  lbwrite('"samp.dll" Base: 0x' + inttohex(dwSAMPBase, 8));
  lbwrite('addposx: 0x' + inttohex(LocPlayer.dwAddPosX, 8));
  lbwrite('addposy: 0x' + inttohex(LocPlayer.dwAddPosY, 8));
  lbwrite('addposz: 0x' + inttohex(LocPlayer.dwAddPosZ, 8));
  lbwrite('addcposx: 0x' +inttohex(LocPlayer.dwAddCPosX,8));
  lbwrite('addcposy: 0x' +inttohex(LocPlayer.dwAddCPosY,8));
  lbwrite('---------');
end;




procedure TForm1.ButtonLoadLocClick(Sender: TObject);
var
  i: integer;
  bSelected: boolean = False;
begin
  Inc(Telecount);
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



procedure TForm1.ButtonDelLocClick(Sender: TObject);
var
  i: integer;
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
          if ListBoxLocations.Selected[i] then
            ListBoxLocations.Items.Delete(i);
        end;
        lbwrite('Location deleted.');
        lbwrite('---------');
      end;

    end
    else
    begin
      for i := ListBoxLocations.Items.Count - 1 downto 0 do
      begin
        if ListBoxLocations.Selected[i] then
          ListBoxLocations.Items.Delete(i);
      end;
      lbwrite('Location deleted.');
      lbwrite('---------');
    end;
  end;
end;

procedure TForm1.ButtonClearLogClick(Sender: TObject);
begin
  ListBoxDebug.Clear;
end;

procedure TForm1.ButtonGetAddressesClick(Sender: TObject);
begin
  GetAddresses();
end;



procedure TForm1.ButtonSaveLocClick(Sender: TObject);
begin
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

  Inc(LBIndexer);
end;

procedure TForm1.CheckBoxAirbrakeChange(Sender: TObject);
begin
  if CheckBoxAirbrake.Checked then begin
    lbwrite('Airbrake-Hotkey enabled! Press X');
    TimerAirbrake.Enabled:=true;
    end
  else begin
    lbwrite('Airbrake disabled.');
    TimerAirbrake.Enabled:=false;
    end;

end;



procedure TForm1.FormCreate(Sender: TObject);
begin
  while hProcess = 0 do
  begin
    hFenster := FindWindow(nil, 'GTA:SA:MP');
    GetWindowThreadProcessId(hFenster, @dwProcId);
    hProcess := OpenProcess(PROCESS_ALL_ACCESS, False, dwProcId);
    if (hProcess = 0) and bGameNotFoundTrigger then
    begin
      ShowMessage('Waiting for Game...');
      bGameNotFoundTrigger := False;
    end;
    Sleep(250);
  end;
  lbwrite('Game found.');
  lbwrite('ProcessID: ' + IntToStr(dwProcId));
  lbwrite('hProcess: ' + IntToStr(hProcess));
  GetAddresses();

  AirBrConf.jinc := 0.25;
  AirBrConf.k := (180 / PI);


  TimerReadPos.Enabled := True;
end;

procedure TForm1.Label1Click(Sender: TObject);
begin

end;

procedure TForm1.LBDebugClick(Sender: TObject);
begin

end;

procedure TForm1.ListBoxLocationsClick(Sender: TObject);
begin
  //ButtonLoadLocClick(Sender);
end;


//STILL NEEDS WORK============================================================
procedure TForm1.TimerAirbrakeTimer(Sender: TObject);
begin

  if AirBrConf.bEnableAirbrake then begin
      WriteFloat(AirBrConf.AbX,LocPlayer.dwAddPosX);
      WriteFloat(AirBrConf.AbY,LocPlayer.dwAddPosY);
      WriteFloat(AirBrConf.AbZ,LocPlayer.dwAddPosZ);
  end;






  if GetAsyncKeyState(VK_X) <> 0 then
  begin
   if AirBrConf.bEnableAirbrake = false then begin
      AirBrConf.AbX:=ReadFloat(LocPlayer.dwAddPosX);
      AirBrConf.AbY:=ReadFloat(LocPlayer.dwAddPosY);
      AirBrConf.AbZ:=ReadFloat(LocPlayer.dwAddPosZ);
      lbwrite(floattostr(AirBrConf.AbX));
      lbwrite(floattostr(AirBrConf.AbY));
      lbwrite(floattostr(AirBrConf.AbZ));

      AirBrConf.bEnableAirbrake:=true;
      lbwrite('ON');
      end
      //lbwrite('bEnableAirbrake: ' + inttostr(bEnableAirbrake));
   else begin
     AirBrConf.bEnableAirbrake:=false;
     WriteFloat(-1000,LocPlayer.dwAddPosZ);
     lbwrite('OFF');
   end;

    while GetAsyncKeyState(VK_X) <> 0 do begin
          Sleep(300);
           //lbwrite('FOO');
           //lbwrite('bEnableAirbrake: ' + IntToStr(bEnableAirbrake));
          end;
    end;



  end;




procedure TForm1.TimerReadPosTimer(Sender: TObject);
begin
  LocPlayer.fX := ReadFloat(LocPlayer.dwAddPosX);
  LocPlayer.fY := ReadFloat(LocPlayer.dwAddPosY);
  LocPlayer.fZ := ReadFloat(LocPlayer.dwAddPosZ);
  LabelPosX.Caption := FloatToStr(LocPlayer.fX);
  LabelPosY.Caption := FloatToStr(LocPlayer.fY);
  LabelPosZ.Caption := FloatToStr(LocPlayer.fZ);
  LabelTelecounter.Caption := 'Teleportation count: ' + IntToStr(Telecount);
end;

end.
