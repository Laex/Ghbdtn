unit Ghbdtn.Password;

interface

uses
  Winapi.Windows;

function LooksLikePasswordControl(AStyle: NativeInt; APasswordChar: Integer): Boolean;
function IsClassicEditClass(const AClassName: string): Boolean;
function AutomationPasswordProbeApplies(const AClassName: string): Boolean;
function IsFocusedPasswordField: Boolean;

implementation

uses
  Winapi.Messages,
  Winapi.ActiveX,
  System.SysUtils,
  Winapi.UIAutomation;

const
  PasswordCacheMs = 250;
  PasswordQueryTimeoutMs = 25;
  PasswordParentDepth = 3;

var
  CachedFocus: HWND;
  CachedIsPassword: Boolean;
  CachedTick: UInt64;
  UiaCachedFocus: HWND;
  UiaCachedPassword: Boolean;
  UiaCachedValid: Boolean;

function LooksLikePasswordControl(AStyle: NativeInt; APasswordChar: Integer): Boolean;
begin
  Result := ((AStyle and ES_PASSWORD) <> 0) or (APasswordChar <> 0);
end;

function IsClassicEditClass(const AClassName: string): Boolean;
begin
  Result := SameText(AClassName, 'Edit') or
    SameText(AClassName, 'RichEdit20W') or
    SameText(AClassName, 'RichEdit20A') or
    SameText(AClassName, 'RICHEDIT50W');
end;

function AutomationPasswordProbeApplies(const AClassName: string): Boolean;
begin
  // Classic edit controls already answer EM_GETPASSWORDCHAR.
  Result := not IsClassicEditClass(AClassName);
end;

function AutomationClient: IUIAutomation;
begin
  Result := nil;
  if Failed(CoCreateInstance(CLSID_CUIAutomation, nil, CLSCTX_INPROC_SERVER,
    IUIAutomation, Result)) then
    Result := nil;
end;

function FocusedElementIsPassword: Boolean;
var
  Client: IUIAutomation;
  Element: IUIAutomationElement;
  Flag: BOOL;
  Init: HRESULT;
begin
  Result := False;
  Init := CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
  if (Init <> S_OK) and (Init <> S_FALSE) then
    Exit;
  try
    try
      Client := AutomationClient;
      if Client = nil then
        Exit;
      Element := nil;
      if Failed(Client.GetFocusedElement(Element)) or (Element = nil) then
        Exit;
      Flag := False;
      if Failed(Element.get_CurrentIsPassword(Flag)) then
        Exit;
      Result := Flag;
    except
      Result := False;
    end;
  finally
    if Init = S_OK then
      CoUninitialize;
  end;
end;

function FocusWindow: HWND;
var
  Foreground: HWND;
  Info: TGUIThreadInfo;
  ThreadId: DWORD;
begin
  Result := 0;
  Foreground := GetForegroundWindow;
  if Foreground = 0 then
    Exit;
  ThreadId := GetWindowThreadProcessId(Foreground, nil);
  ZeroMemory(@Info, SizeOf(Info));
  Info.cbSize := SizeOf(Info);
  if GetGUIThreadInfo(ThreadId, Info) and (Info.hwndFocus <> 0) then
    Result := Info.hwndFocus
  else
    Result := Foreground;
end;

function WindowIsPassword(AWindow: HWND): Boolean;
var
  Style: NativeInt;
  PasswordChar: DWORD_PTR;
begin
  Result := False;
  if (AWindow = 0) or not IsWindow(AWindow) then
    Exit;
  Style := GetWindowLong(AWindow, GWL_STYLE);
  PasswordChar := 0;
  SendMessageTimeout(AWindow, EM_GETPASSWORDCHAR, 0, 0,
    SMTO_ABORTIFHUNG or SMTO_NORMAL, PasswordQueryTimeoutMs, @PasswordChar);
  Result := LooksLikePasswordControl(Style, Integer(PasswordChar));
end;

function IsFocusedPasswordField: Boolean;
var
  Current: HWND;
  Steps: Integer;
  ClassName: array[0..127] of Char;
begin
  Current := FocusWindow;
  if (Current = CachedFocus) and
     (GetTickCount64 - CachedTick <= PasswordCacheMs) then
    Exit(CachedIsPassword);

  CachedFocus := Current;
  CachedTick := GetTickCount64;
  CachedIsPassword := False;
  Steps := 0;
  while (Current <> 0) and (Steps < PasswordParentDepth) do
  begin
    if WindowIsPassword(Current) then
    begin
      CachedIsPassword := True;
      Break;
    end;
    Current := GetParent(Current);
    Inc(Steps);
  end;

  Current := CachedFocus;
  if not CachedIsPassword and (Current <> 0) and
     (GetClassName(Current, ClassName, Length(ClassName)) > 0) and
     AutomationPasswordProbeApplies(ClassName) then
  begin
    // One UI Automation query per focus. Repeating it on every key would
    // stall the low-level hook if the target is slow.
    if (not UiaCachedValid) or (UiaCachedFocus <> Current) then
    begin
      UiaCachedFocus := Current;
      UiaCachedValid := True;
      UiaCachedPassword := FocusedElementIsPassword;
    end;
    if UiaCachedPassword then
      CachedIsPassword := True;
  end;
  Result := CachedIsPassword;
end;

end.
