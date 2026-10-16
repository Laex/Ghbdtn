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
{ The control that has the keyboard focus in the foreground window, or 0. }
function ForegroundFocusWindow: HWND;

var
  PauseKeyboardHook: procedure;
  ResumeKeyboardHook: procedure;
function ResolveInputTargetWindow(AForegroundWindow: HWND): HWND;
function EnsureModifiersReleased: Boolean;
function SendMarkedKey(AVirtualKey: Word; AKeyUp: Boolean = False;
  AScanCode: Word = 0; AFlags: DWORD = 0): Boolean;
function SendMarkedKeyPress(AVirtualKey: Word): Boolean;
{ Presses an arrow key ACount times, with Shift held to extend a selection. }
function SendMarkedArrow(AVirtualKey: Word; ACount: Integer;
  AWithShift: Boolean): Boolean;
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
  UnicodeCharGapMs = 3;
  BackspaceSettleMs = 15;
  PauseHookForReplacement = False;
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

function ForegroundFocusWindow: HWND;
var
  Info: TGUIThreadInfo;
  Foreground: HWND;
  ThreadId: DWORD;
begin
  Result := 0;
  Foreground := GetForegroundWindow;
  if Foreground = 0 then
    Exit;
  ThreadId := GetWindowThreadProcessId(Foreground, nil);
  ZeroMemory(@Info, SizeOf(Info));
  Info.cbSize := SizeOf(Info);
  if GetGUIThreadInfo(ThreadId, Info) then
    Result := Info.hwndFocus;
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

function SendMarkedArrow(AVirtualKey: Word; ACount: Integer;
  AWithShift: Boolean): Boolean;
const
  ArrowChunk = 256;
var
  Inputs: TArray<TInput>;
  Done, Count, I, Index: Integer;
begin
  Result := True;
  if ACount <= 0 then
    Exit;
  if AWithShift then
    Result := SendMarkedKey(VK_SHIFT);
  Done := 0;
  while Result and (Done < ACount) do
  begin
    Count := ACount - Done;
    if Count > ArrowChunk then
      Count := ArrowChunk;
    SetLength(Inputs, Count * 2);
    ZeroMemory(@Inputs[0], Length(Inputs) * SizeOf(TInput));
    for I := 0 to Count - 1 do
    begin
      Index := I * 2;
      Inputs[Index].Itype := INPUT_KEYBOARD;
      Inputs[Index].ki.wVk := AVirtualKey;
      Inputs[Index].ki.dwFlags := KEYEVENTF_EXTENDEDKEY;
      Inputs[Index].ki.dwExtraInfo := GHBDTN_INPUT_SIGNATURE;
      Inputs[Index + 1] := Inputs[Index];
      Inputs[Index + 1].ki.dwFlags := KEYEVENTF_EXTENDEDKEY or KEYEVENTF_KEYUP;
    end;
    Result := SendInputsWithRetry(Inputs);
    Inc(Done, Count);
  end;
  if AWithShift then
    SendMarkedKey(VK_SHIFT, True);
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
  Count, Index, I, Attempt, Slice: Integer;
  Sent: Boolean;
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

  // With PauseHookForReplacement the hook is removed for the whole sequence;
  // otherwise a key typed meanwhile is queued by the hook behind the
  // replacement. Each Unicode character is sent on its own: a target that has
  // not yet read the earlier characters of one large batch turns all of them
  // into the last one.
  if PauseHookForReplacement then
  begin
    if Assigned(PauseKeyboardHook) then
      PauseKeyboardHook;
    AtomicIncrement(InjectingInput);
  end;
  try
    Result := True;
    Index := 0;
    while Result and (Index < Count) do
    begin
      if Index < ABackspaces * 2 then
        Slice := ABackspaces * 2
      else
        Slice := 2;
      if Index + Slice > Count then
        Slice := Count - Index;
      Sent := False;
      for Attempt := 1 to SendRetryCount do
      begin
        if SendInput(Slice, Inputs[Index], SizeOf(TInput)) = UINT(Slice) then
        begin
          Sent := True;
          Break;
        end;
        if Attempt < SendRetryCount then
          Sleep(SendRetryDelayMs);
      end;
      Result := Sent;
      Inc(Index, Slice);
      if Result and (Index < Count) then
        if Index <= ABackspaces * 2 then
          Sleep(BackspaceSettleMs)
        else
          Sleep(UnicodeCharGapMs);
    end;
  finally
    if PauseHookForReplacement then
    begin
      AtomicDecrement(InjectingInput);
      if Assigned(ResumeKeyboardHook) then
        ResumeKeyboardHook;
    end;
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
