unit Ghbdtn.Layout;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils;

const
  LANGID_RU = $0419;
  LANGID_EN = $0409;
  INPUTLANGCHANGE_FORWARD = $0002;

type
  TLangKind = (lkUnknown, lkRU, lkEN);

function GetForegroundKeyboardLayout: HKL;
function GetForegroundLangKind: TLangKind;
function LangKindToString(ALang: TLangKind): string;
function HKLToLangKind(AHKL: HKL): TLangKind;
function GetHKLForLang(ALang: TLangKind): HKL;
procedure SwitchForegroundKeyboardLayout(ATargetLang: TLangKind = lkUnknown);
{ Waits until the foreground window reports ALang as its layout. The switch
  request is asynchronous: a key typed before the window applies it is typed
  on the old layout. }
function WaitForForegroundLang(ALang: TLangKind; ATimeoutMs: Cardinal): Boolean;
{ Calls ARequest until AConfirmed reports the change, at most AAttempts
  times. A window busy with input may drop a switch request, and a request
  for an explicit layout is harmless to repeat. }
function RequestUntilConfirmed(const ARequest: TProc;
  const AConfirmed: TFunc<Boolean>; AAttempts: Integer): Boolean;
{ Switches the foreground window to ALang and waits for it to apply the
  switch. False when the window still reports another layout. }
function SwitchForegroundLayoutConfirmed(ALang: TLangKind;
  ATimeoutMs: Cardinal): Boolean;

function ConvertCharSwap(AChar: Char): Char;
function ConvertStringSwap(const AText: string): string;
function MapVirtualKeyToChar(VKCode: DWORD; IsShift: Boolean; ALang: TLangKind): Char;

// Whether a character of the English layout is typed by a key that is a
// Russian letter on the Russian layout: , . ; ' [ ] ` and the shifted forms
// of those, including ":" (Shift+;, the capital "Ж"). Such a character is
// punctuation or part of a Russian word.
function IsRussianLetterKey(AChar: Char): Boolean;

implementation

const
  EnLower = 'qwertyuiop[]asdfghjkl;''zxcvbnm,./`';
  RuLower = 'йцукенгшщзхъфывапролджэячсмитьбю.ё';

  EnUpper = 'QWERTYUIOP{}ASDFGHJKL:"ZXCVBNM<>?~@#$%^&*()_+';
  RuUpper = 'ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,Ё"№;%:?*()_+';

  VKOrder: array[0..33] of DWORD = (
    $51, $57, $45, $52, $54, $59, $55, $49, $4F, $50, VK_OEM_4, VK_OEM_6,
    $41, $53, $44, $46, $47, $48, $4A, $4B, $4C, VK_OEM_1, VK_OEM_7,
    $5A, $58, $43, $56, $42, $4E, $4D, VK_OEM_COMMA, VK_OEM_PERIOD, VK_OEM_2, VK_OEM_3
  );

function GetForegroundKeyboardLayout: HKL;
var
  TargetWnd: HWND;
  Info: TGUIThreadInfo;
  ThreadId: DWORD;
begin
  // Do not AttachThreadInput here. Doing that from the keyboard hook or while
  // another thread is sending input to the foreground window deadlocks and
  // Windows terminates the process with no dialog.
  Result := GetKeyboardLayout(0);
  TargetWnd := GetForegroundWindow;
  if TargetWnd = 0 then
    Exit;
  ThreadId := GetWindowThreadProcessId(TargetWnd, nil);
  ZeroMemory(@Info, SizeOf(Info));
  Info.cbSize := SizeOf(Info);
  if GetGUIThreadInfo(ThreadId, Info) then
  begin
    if Info.hwndFocus <> 0 then
      ThreadId := GetWindowThreadProcessId(Info.hwndFocus, nil)
    else if Info.hwndCaret <> 0 then
      ThreadId := GetWindowThreadProcessId(Info.hwndCaret, nil);
  end;
  if ThreadId <> 0 then
    Result := GetKeyboardLayout(ThreadId);
end;

function HKLToLangKind(AHKL: HKL): TLangKind;
var
  PrimaryLangID: WORD;
begin
  PrimaryLangID := WORD(UIntPtr(AHKL) and $03FF);
  case PrimaryLangID of
    $19: Result := lkRU; // LANG_RUSSIAN
    $09: Result := lkEN; // LANG_ENGLISH
  else
    Result := lkUnknown;
  end;
end;

function GetForegroundLangKind: TLangKind;
begin
  Result := HKLToLangKind(GetForegroundKeyboardLayout);
end;

function LangKindToString(ALang: TLangKind): string;
var
  CurHKL: HKL;
  LangID: LCID;
  Buffer: array[0..9] of Char;
begin
  case ALang of
    lkRU: Exit('RU');
    lkEN: Exit('EN');
  end;

  CurHKL := GetForegroundKeyboardLayout;
  LangID := LCID(WORD(UIntPtr(CurHKL) and $FFFF));
  if GetLocaleInfo(LangID, LOCALE_SISO639LANGNAME, Buffer, Length(Buffer)) > 0 then
    Result := UpperCase(String(Buffer))
  else
    Result := '??';

  if Length(Result) > 2 then
    Result := Copy(Result, 1, 2);
end;

function GetHKLForLang(ALang: TLangKind): HKL;
var
  TargetID: string;
begin
  case ALang of
    lkRU: TargetID := '00000419';
    lkEN: TargetID := '00000409';
  else
    Exit(0);
  end;
  Result := LoadKeyboardLayout(PChar(TargetID), KLF_ACTIVATE);
end;

procedure SwitchForegroundKeyboardLayout(ATargetLang: TLangKind);
var
  ForegroundWnd: HWND;
  FocusRoot: HWND;
  TargetHKL: HKL;
  Info: TGUIThreadInfo;
begin
  ForegroundWnd := GetForegroundWindow;
  if ForegroundWnd = 0 then Exit;

  if ATargetLang = lkUnknown then
  begin
    // A cycle request is sent once: every extra copy would step again.
    PostMessage(ForegroundWnd, WM_INPUTLANGCHANGEREQUEST, 0,
      INPUTLANGCHANGE_FORWARD);
    Exit;
  end;

  TargetHKL := GetHKLForLang(ATargetLang);
  PostMessage(ForegroundWnd, WM_INPUTLANGCHANGEREQUEST, 0, LPARAM(TargetHKL));

  // A control with the focus is a child window and ignores the request; the
  // top-level window above it takes it. When that window is not the
  // foreground one (a host window of another thread), it gets the request
  // too. Repeating an explicit layout is harmless.
  ZeroMemory(@Info, SizeOf(Info));
  Info.cbSize := SizeOf(Info);
  if GetGUIThreadInfo(GetWindowThreadProcessId(ForegroundWnd, nil), Info) and
     (Info.hwndFocus <> 0) then
  begin
    FocusRoot := GetAncestor(Info.hwndFocus, GA_ROOT);
    if (FocusRoot <> 0) and (FocusRoot <> ForegroundWnd) then
      PostMessage(FocusRoot, WM_INPUTLANGCHANGEREQUEST, 0, LPARAM(TargetHKL));
  end;
end;

function WaitForForegroundLang(ALang: TLangKind; ATimeoutMs: Cardinal): Boolean;
var
  Deadline: UInt64;
begin
  Deadline := GetTickCount64 + ATimeoutMs;
  repeat
    if GetForegroundLangKind = ALang then
      Exit(True);
    Sleep(4);
  until GetTickCount64 >= Deadline;
  Result := False;
end;

function RequestUntilConfirmed(const ARequest: TProc;
  const AConfirmed: TFunc<Boolean>; AAttempts: Integer): Boolean;
var
  Attempt: Integer;
begin
  for Attempt := 1 to AAttempts do
  begin
    ARequest();
    if AConfirmed() then
      Exit(True);
  end;
  Result := False;
end;

function SwitchForegroundLayoutConfirmed(ALang: TLangKind;
  ATimeoutMs: Cardinal): Boolean;
const
  SwitchAttempts = 2;
begin
  Result := RequestUntilConfirmed(
    procedure
    begin
      SwitchForegroundKeyboardLayout(ALang);
    end,
    function: Boolean
    begin
      Result := WaitForForegroundLang(ALang, ATimeoutMs);
    end, SwitchAttempts);
end;

function ConvertCharSwap(AChar: Char): Char;
var
  Idx: Integer;
begin
  Result := AChar;

  // Latin lower -> Cyrillic lower
  Idx := Pos(AChar, EnLower);
  if Idx > 0 then
    Exit(RuLower[Idx]);

  // Latin upper -> Cyrillic upper
  Idx := Pos(AChar, EnUpper);
  if Idx > 0 then
    Exit(RuUpper[Idx]);

  // Cyrillic lower -> Latin lower
  Idx := Pos(AChar, RuLower);
  if Idx > 0 then
    Exit(EnLower[Idx]);

  // Cyrillic upper -> Latin upper
  Idx := Pos(AChar, RuUpper);
  if Idx > 0 then
    Exit(EnUpper[Idx]);
end;

function ConvertStringSwap(const AText: string): string;
var
  I: Integer;
begin
  SetLength(Result, Length(AText));
  for I := 1 to Length(AText) do
    Result[I] := ConvertCharSwap(AText[I]);
end;

function IsRussianLetterKey(AChar: Char): Boolean;
begin
  Result := CharInSet(AChar, [',', '.', ';', '''', '[', ']', '`', ':', '<', '>',
    '"', '{', '}', '~']);
end;

function MapVirtualKeyToChar(VKCode: DWORD; IsShift: Boolean; ALang: TLangKind): Char;
var
  I: Integer;
begin
  Result := #0;

  for I := Low(VKOrder) to High(VKOrder) do
  begin
    if VKOrder[I] <> VKCode then
      Continue;

    if ALang = lkRU then
    begin
      if IsShift then
        Exit(RuUpper[I + 1]);
      Exit(RuLower[I + 1]);
    end;

    if IsShift then
      Exit(EnUpper[I + 1]);
    Exit(EnLower[I + 1]);
  end;

  if VKCode = VK_OEM_MINUS then
  begin
    if IsShift then
      Exit('_')
    else
      Exit('-');
  end;
  if VKCode = VK_OEM_PLUS then
  begin
    if IsShift then
      Exit('+')
    else
      Exit('=');
  end;

  if (VKCode >= Ord('0')) and (VKCode <= Ord('9')) then
    Result := Char(VKCode);
end;

end.
