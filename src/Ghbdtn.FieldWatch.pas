unit Ghbdtn.FieldWatch;

interface

uses
  System.Classes,
  System.SyncObjs,
  System.SysUtils;

type
  TSecureFieldKind = (sfPassword, sfEmail);
  TSecureFieldEvent = reference to procedure(AKind: TSecureFieldKind);

{ Labels that mark an e-mail input. The label has to start with the marker:
  a search box named "Search mail" takes ordinary text. }
function IsEmailFieldName(const AName: string): Boolean;

{ Watches which control has the keyboard focus (through UI Automation, on its
  own thread, so a slow application cannot stall typing) and reports each
  time focus moves into a password or an e-mail field. The event runs on the
  main thread. }
type
  TFieldWatcher = class(TThread)
  private
    FOnEntered: TSecureFieldEvent;
    FStop: TEvent;
  protected
    procedure Execute; override;
    procedure TerminatedSet; override;
  public
    constructor Create(const AOnEntered: TSecureFieldEvent);
    destructor Destroy; override;
  end;

implementation

uses
  Winapi.Windows,
  Winapi.ActiveX,
  System.StrUtils,
  Winapi.UIAutomation,
  Ghbdtn.Settings;

const
  EmailPrefixes: array[0..7] of string = (
    'email', 'e-mail', 'e mail', 'электронная почта',
    'электронный адрес', 'адрес электронной почты', 'эл. почта', 'эл.почта');

function IsEmailFieldName(const AName: string): Boolean;
var
  Name, Prefix: string;
begin
  Name := Trim(AName).ToLower;
  if Name = '' then
    Exit(False);
  if (Name = 'почта') or (Name = 'mail') then
    Exit(True);
  for Prefix in EmailPrefixes do
    if StartsStr(Prefix, Name) then
      Exit(True);
  Result := False;
end;

type
  { Receives focus-change notifications from UI Automation on one of its own
    threads. Detach makes a late notification a no-op once the watcher is
    gone. }
  TFocusHandler = class(TInterfacedObject, IUIAutomationFocusChangedEventHandler)
  private
    FLock: TCriticalSection;
    FOnEntered: TSecureFieldEvent;
    FLastIdentity: string;
    procedure Report(AKind: TSecureFieldKind);
  public
    constructor Create(const AOnEntered: TSecureFieldEvent);
    destructor Destroy; override;
    procedure Detach;
    function HandleFocusChangedEvent(sender: IUIAutomationElement): HRESULT; stdcall;
  end;

constructor TFocusHandler.Create(const AOnEntered: TSecureFieldEvent);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FOnEntered := AOnEntered;
end;

destructor TFocusHandler.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TFocusHandler.Detach;
begin
  FLock.Enter;
  try
    FOnEntered := nil;
  finally
    FLock.Leave;
  end;
end;

procedure TFocusHandler.Report(AKind: TSecureFieldKind);
var
  Callback: TSecureFieldEvent;
begin
  Callback := FOnEntered;
  if not Assigned(Callback) then
    Exit;
  TThread.Queue(nil,
    procedure
    begin
      Callback(AKind);
    end);
end;

function TFocusHandler.HandleFocusChangedEvent(
  sender: IUIAutomationElement): HRESULT;
var
  Identity: string;
  NamePtr, IdPtr: PWideChar;
  Name, AutomationId: string;
  ControlType: Cardinal;
  IsPassword: BOOL;
  Handle: HWND;
  Kind: TSecureFieldKind;
  Entered: Boolean;
begin
  Result := S_OK;
  if (sender = nil) or not AppSettings.EnglishInSecureFields then
  begin
    FLock.Enter;
    try
      FLastIdentity := '';
    finally
      FLock.Leave;
    end;
    Exit;
  end;
  try
    NamePtr := nil;
    IdPtr := nil;
    Handle := 0;
    ControlType := 0;
    IsPassword := False;
    if Succeeded(sender.get_CurrentName(NamePtr)) and (NamePtr <> nil) then
    begin
      Name := NamePtr;
      SysFreeString(NamePtr);
    end
    else
      Name := '';
    if Succeeded(sender.get_CurrentAutomationId(IdPtr)) and (IdPtr <> nil) then
    begin
      AutomationId := IdPtr;
      SysFreeString(IdPtr);
    end
    else
      AutomationId := '';
    sender.get_CurrentNativeWindowHandle(Handle);
    sender.get_CurrentControlType(ControlType);
    sender.get_CurrentIsPassword(IsPassword);
    Identity := IntToStr(Handle) + '|' + AutomationId + '|' + Name + '|' +
      IntToStr(ControlType);
    FLock.Enter;
    try
      if Identity = FLastIdentity then
        Exit;
      FLastIdentity := Identity;
      Entered := False;
      Kind := sfPassword;
      if IsPassword then
        Entered := True
      else if (ControlType = UIA_EditControlTypeId) and
              IsEmailFieldName(Name) then
      begin
        Entered := True;
        Kind := sfEmail;
      end;
      if Entered then
        Report(Kind);
    finally
      FLock.Leave;
    end;
  except
    FLock.Enter;
    try
      FLastIdentity := '';
    finally
      FLock.Leave;
    end;
  end;
end;

constructor TFieldWatcher.Create(const AOnEntered: TSecureFieldEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOnEntered := AOnEntered;
  FStop := TEvent.Create(nil, True, False, '');
end;

destructor TFieldWatcher.Destroy;
begin
  FStop.Free;
  inherited;
end;

procedure TFieldWatcher.TerminatedSet;
begin
  inherited;
  FStop.SetEvent;
end;

{ The thread only owns the COM apartment and the subscription; it sleeps until
  stopped, so an idle watcher costs no CPU. }
procedure TFieldWatcher.Execute;
var
  Init: HRESULT;
  Client: IUIAutomation;
  Handler: TFocusHandler;
  HandlerIntf: IUIAutomationFocusChangedEventHandler;
begin
  Init := CoInitializeEx(nil, COINIT_MULTITHREADED);
  try
    if Failed(CoCreateInstance(CLSID_CUIAutomation, nil, CLSCTX_INPROC_SERVER,
      IUIAutomation, Client)) then
      Exit;
    Handler := TFocusHandler.Create(FOnEntered);
    HandlerIntf := Handler;
    try
      if Failed(Client.AddFocusChangedEventHandler(nil, HandlerIntf)) then
        Exit;
      try
        FStop.WaitFor(INFINITE);
      finally
        Client.RemoveFocusChangedEventHandler(HandlerIntf);
      end;
    finally
      Handler.Detach;
      HandlerIntf := nil;
      Client := nil;
    end;
  finally
    if (Init = S_OK) or (Init = S_FALSE) then
      CoUninitialize;
  end;
end;

end.
