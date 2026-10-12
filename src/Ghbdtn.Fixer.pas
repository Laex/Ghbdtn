unit Ghbdtn.Fixer;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils;

const
  GHBDTN_INPUT_SIGNATURE: ULONG_PTR = ULONG_PTR($47484244544E5632);

function IsOwnInput(AExtraInfo: ULONG_PTR): Boolean;
function IsInjectingInput: Boolean;
function IsTargetWindowValid(ATargetWindow: HWND): Boolean;

var
  PauseKeyboardHook: procedure;
  ResumeKeyboardHook: procedure;
function ResolveInputTargetWindow(AForegroundWindow: HWND): HWND;
function EnsureModifiersReleased: Boolean;
function SendMarkedKey(AVirtualKey: Word; AKeyUp: Boolean = False;
  AScanCode: Word = 0; AFlags: DWORD = 0): Boolean;
function SendMarkedKeyPress(AVirtualKey: Word): Boolean;
function SendMarkedShortcut(AModifier, AKey: Word): Boolean;
function SendMarkedUnicode(const AText: string): Boolean;
function SendMarkedBackspaces(ACount: Integer): Boolean;
function SendMarkedWordReplacement(ABackspaces: Integer; const AText: string;
  ATrailingKey: Word): Boolean;
function SendMarkedReplay(AVirtualKey, AScanCode: Word; AFlags: DWORD): Boolean;
function TryCopySelection(ATargetWindow: HWND): Boolean;
function TryPasteClipboard(ATargetWindow: HWND): Boolean;
function TryReplaceSelection(ATargetWindow: HWND; const AText: string): Boolean;

implementation

const
  SendRetryCount = 3;
  SendRetryDelayMs = 5;
  ModifierReleaseAttempts = 10;
  ModifierReleaseDelayMs = 10;

var
  InjectingInput: Integer;

function IsOwnInput(AExtraInfo: ULONG_PTR): Boolean;
begin
  Result := AExtraInfo = GHBDTN_INPUT_SIGNATURE;
end;

function IsInjectingInput: Boolean;
begin
  Result := AtomicIncrement(InjectingInput, 0) > 0;
end;

function IsTargetWindowValid(ATargetWindow: HWND): Boolean;
begin
  Result := (ATargetWindow <> 0) and IsWindow(ATargetWindow) and
    (GetForegroundWindow = ATargetWindow);
end;

function ResolveInputTargetWindow(AForegroundWindow: HWND): HWND;
var
  Info: TGUIThreadInfo;
  ThreadId: DWORD;
begin
  Result := AForegroundWindow;
  if AForegroundWindow = 0 then
    Exit;
  ThreadId := GetWindowThreadProcessId(AForegroundWindow, nil);
  ZeroMemory(@Info, SizeOf(Info));
  Info.cbSize := SizeOf(Info);
  if GetGUIThreadInfo(ThreadId, Info) then
  begin
    if (Info.hwndFocus <> 0) and IsWindow(Info.hwndFocus) then
      Exit(Info.hwndFocus);
    if (Info.hwndCaret <> 0) and IsWindow(Info.hwndCaret) then
      Exit(Info.hwndCaret);
  end;
end;

function SendInputsWithRetry(var AInputs: array of TInput): Boolean;
var
  Attempt: Integer;
begin
  Result := False;
  if Length(AInputs) = 0 then
    Exit;
  AtomicIncrement(InjectingInput);
  try
    for Attempt := 1 to SendRetryCount do
    begin
      if SendInput(Length(AInputs), AInputs[0], SizeOf(TInput)) =
         UINT(Length(AInputs)) then
        Exit(True);
      if Attempt < SendRetryCount then
        Sleep(SendRetryDelayMs);
    end;
  finally
    AtomicDecrement(InjectingInput);
  end;
end;

function SendMarkedKey(AVirtualKey: Word; AKeyUp: Boolean;
  AScanCode: Word; AFlags: DWORD): Boolean;
var
  Input: array[0..0] of TInput;
begin
  ZeroMemory(@Input[0], SizeOf(Input[0]));
  Input[0].Itype := INPUT_KEYBOARD;
  Input[0].ki.wVk := AVirtualKey;
  Input[0].ki.wScan := AScanCode;
  Input[0].ki.dwFlags := AFlags;
  if AKeyUp then
    Input[0].ki.dwFlags := Input[0].ki.dwFlags or KEYEVENTF_KEYUP;
  Input[0].ki.dwExtraInfo := GHBDTN_INPUT_SIGNATURE;
  Result := SendInputsWithRetry(Input);
end;

function EnsureModifiersReleased: Boolean;
var
  Attempt: Integer;
begin
  Result := False;
  for Attempt := 1 to ModifierReleaseAttempts do
  begin
    if ((GetAsyncKeyState(VK_SHIFT) and $8000) = 0) and
       ((GetAsyncKeyState(VK_LSHIFT) and $8000) = 0) and
       ((GetAsyncKeyState(VK_RSHIFT) and $8000) = 0) and
       ((GetAsyncKeyState(VK_CONTROL) and $8000) = 0) and
       ((GetAsyncKeyState(VK_MENU) and $8000) = 0) then
      Exit(True);
    SendMarkedKey(VK_LSHIFT, True);
    SendMarkedKey(VK_RSHIFT, True);
    SendMarkedKey(VK_SHIFT, True);
    SendMarkedKey(VK_CONTROL, True);
    SendMarkedKey(VK_MENU, True);
    Sleep(ModifierReleaseDelayMs);
  end;
end;

function SendMarkedKeyPress(AVirtualKey: Word): Boolean;
var
  Inputs: array[0..1] of TInput;
begin
  ZeroMemory(@Inputs[0], SizeOf(Inputs));
  Inputs[0].Itype := INPUT_KEYBOARD;
  Inputs[0].ki.wVk := AVirtualKey;
  Inputs[0].ki.dwExtraInfo := GHBDTN_INPUT_SIGNATURE;
  Inputs[1] := Inputs[0];
  Inputs[1].ki.dwFlags := KEYEVENTF_KEYUP;
  Result := SendInputsWithRetry(Inputs);
end;

function SendMarkedShortcut(AModifier, AKey: Word): Boolean;
var
  Inputs: array[0..3] of TInput;
  I: Integer;
begin
  ZeroMemory(@Inputs[0], SizeOf(Inputs));
  for I := Low(Inputs) to High(Inputs) do
  begin
    Inputs[I].Itype := INPUT_KEYBOARD;
    Inputs[I].ki.dwExtraInfo := GHBDTN_INPUT_SIGNATURE;
  end;
  Inputs[0].ki.wVk := AModifier;
  Inputs[1].ki.wVk := AKey;
  Inputs[2].ki.wVk := AKey;
  Inputs[2].ki.dwFlags := KEYEVENTF_KEYUP;
  Inputs[3].ki.wVk := AModifier;
  Inputs[3].ki.dwFlags := KEYEVENTF_KEYUP;
  Result := SendInputsWithRetry(Inputs);
end;

function SendUnicodeChar(ACode: Word): Boolean;
var
  Inputs: array[0..1] of TInput;
begin
  ZeroMemory(@Inputs[0], SizeOf(Inputs));
  Inputs[0].Itype := INPUT_KEYBOARD;
  Inputs[0].ki.wScan := ACode;
  Inputs[0].ki.dwFlags := KEYEVENTF_UNICODE;
  Inputs[1].Itype := INPUT_KEYBOARD;
  Inputs[1].ki.wScan := ACode;
  Inputs[1].ki.dwFlags := KEYEVENTF_UNICODE or KEYEVENTF_KEYUP;
  Result := SendInput(2, Inputs[0], SizeOf(TInput)) = 2;
end;

function SendMarkedUnicode(const AText: string): Boolean;
var
  I: Integer;
begin
  Result := True;
  if AText = '' then
    Exit;
  // A low-level keyboard hook corrupts KEYEVENTF_UNICODE for non-ASCII
  // characters into a stuck Y. The hook must be removed for the duration.
  if Assigned(PauseKeyboardHook) then
    PauseKeyboardHook;
  AtomicIncrement(InjectingInput);
  try
    for I := 1 to Length(AText) do
      if not SendUnicodeChar(Word(AText[I])) then
        Result := False;
  finally
    AtomicDecrement(InjectingInput);
    if Assigned(ResumeKeyboardHook) then
      ResumeKeyboardHook;
  end;
end;

function SendMarkedBackspaces(ACount: Integer): Boolean;
var
  Inputs: TArray<TInput>;
  I, Index: Integer;
begin
  Result := True;
  if ACount <= 0 then
    Exit;
  SetLength(Inputs, ACount * 2);
  FillChar(Inputs[0], Length(Inputs) * SizeOf(TInput), 0);
  Index := 0;
  for I := 1 to ACount do
  begin
    Inputs[Index].Itype := INPUT_KEYBOARD;
    Inputs[Index].ki.wVk := VK_BACK;
    Inputs[Index].ki.dwExtraInfo := GHBDTN_INPUT_SIGNATURE;
    Inputs[Index + 1] := Inputs[Index];
    Inputs[Index + 1].ki.dwFlags := KEYEVENTF_KEYUP;
    Inc(Index, 2);
  end;
  Result := SendInputsWithRetry(Inputs);
end;

function SendMarkedWordReplacement(ABackspaces: Integer; const AText: string;
  ATrailingKey: Word): Boolean;
var
  Inputs: TArray<TInput>;
  Count, Index, I, Attempt: Integer;
begin
  if ABackspaces < 0 then
    ABackspaces := 0;
  if (ABackspaces = 0) and (AText = '') and (ATrailingKey = 0) then
    Exit(True);
  Count := ABackspaces * 2 + Length(AText) * 2;
  if ATrailingKey <> 0 then
    Inc(Count, 2);
  SetLength(Inputs, Count);
  FillChar(Inputs[0], Count * SizeOf(TInput), 0);
  Index := 0;
  for I := 1 to ABackspaces do
  begin
    Inputs[Index].Itype := INPUT_KEYBOARD;
    Inputs[Index].ki.wVk := VK_BACK;
    Inputs[Index].ki.dwExtraInfo := GHBDTN_INPUT_SIGNATURE;
    Inputs[Index + 1] := Inputs[Index];
    Inputs[Index + 1].ki.dwFlags := KEYEVENTF_KEYUP;
    Inc(Index, 2);
  end;
  for I := 1 to Length(AText) do
  begin
    Inputs[Index].Itype := INPUT_KEYBOARD;
    Inputs[Index].ki.wScan := Word(AText[I]);
    Inputs[Index].ki.dwFlags := KEYEVENTF_UNICODE;
    Inputs[Index].ki.dwExtraInfo := GHBDTN_INPUT_SIGNATURE;
    Inputs[Index + 1] := Inputs[Index];
    Inputs[Index + 1].ki.dwFlags := KEYEVENTF_UNICODE or KEYEVENTF_KEYUP;
    Inc(Index, 2);
  end;
  if ATrailingKey <> 0 then
  begin
    Inputs[Index].Itype := INPUT_KEYBOARD;
    Inputs[Index].ki.wVk := ATrailingKey;
    Inputs[Index].ki.dwExtraInfo := GHBDTN_INPUT_SIGNATURE;
    Inputs[Index + 1] := Inputs[Index];
    Inputs[Index + 1].ki.dwFlags := KEYEVENTF_KEYUP;
  end;

  // Backspaces and the replacement are one packet, so the editor cannot
  // insert the new text before the old letters are gone.
  if Assigned(PauseKeyboardHook) then
    PauseKeyboardHook;
  AtomicIncrement(InjectingInput);
  try
    Result := False;
    for Attempt := 1 to SendRetryCount do
    begin
      if SendInput(Count, Inputs[0], SizeOf(TInput)) = UINT(Count) then
        Exit(True);
      if Attempt < SendRetryCount then
        Sleep(SendRetryDelayMs);
    end;
  finally
    AtomicDecrement(InjectingInput);
    if Assigned(ResumeKeyboardHook) then
      ResumeKeyboardHook;
  end;
end;

function SendMarkedReplay(AVirtualKey, AScanCode: Word; AFlags: DWORD): Boolean;
begin
  Result := SendMarkedKey(AVirtualKey, (AFlags and KEYEVENTF_KEYUP) <> 0,
    AScanCode, AFlags and not KEYEVENTF_KEYUP);
end;

function TryCopySelection(ATargetWindow: HWND): Boolean;
begin
  Result := False;
  if not IsTargetWindowValid(ATargetWindow) then
    Exit;
  EnsureModifiersReleased;
  Result := SendMarkedShortcut(VK_CONTROL, Ord('C'));
end;

function TryPasteClipboard(ATargetWindow: HWND): Boolean;
begin
  Result := False;
  if not IsTargetWindowValid(ATargetWindow) then
    Exit;
  EnsureModifiersReleased;
  Result := SendMarkedShortcut(VK_CONTROL, Ord('V'));
end;

function TryReplaceSelection(ATargetWindow: HWND; const AText: string): Boolean;
begin
  // Caller puts AText on the clipboard. Paste replaces the still-active
  // selection and does not inject Unicode through the keyboard hook.
  Result := (AText <> '') and TryPasteClipboard(ATargetWindow);
end;

end.
