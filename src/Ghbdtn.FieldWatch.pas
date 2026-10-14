unit Ghbdtn.FieldWatch;

interface

uses
  System.Classes,
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
    procedure Report(AKind: TSecureFieldKind);
  protected
    procedure Execute; override;
  public
    constructor Create(const AOnEntered: TSecureFieldEvent);
  end;

implementation

uses
  Winapi.Windows,
  Winapi.ActiveX,
  System.StrUtils,
  Winapi.UIAutomation,
  Ghbdtn.Settings;

const
  WatchIntervalMs = 250;
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

constructor TFieldWatcher.Create(const AOnEntered: TSecureFieldEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOnEntered := AOnEntered;
end;

procedure TFieldWatcher.Report(AKind: TSecureFieldKind);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(FOnEntered) then
        FOnEntered(AKind);
    end);
end;

procedure TFieldWatcher.Execute;
var
  Init: HRESULT;
  Client: IUIAutomation;
  Element: IUIAutomationElement;
  Identity, LastIdentity: string;
  NamePtr, IdPtr: PWideChar;
  Name, AutomationId: string;
  ControlType: Cardinal;
  IsPassword: BOOL;
  Handle: HWND;
  Kind: TSecureFieldKind;
  Entered: Boolean;
begin
  Init := CoInitializeEx(nil, COINIT_MULTITHREADED);
  try
    if Failed(CoCreateInstance(CLSID_CUIAutomation, nil, CLSCTX_INPROC_SERVER,
      IUIAutomation, Client)) then
      Exit;
    LastIdentity := '';
    while not Terminated do
    begin
      Sleep(WatchIntervalMs);
      if not AppSettings.EnglishInSecureFields then
      begin
        LastIdentity := '';
        Continue;
      end;
      try
        Element := nil;
        if Failed(Client.GetFocusedElement(Element)) or (Element = nil) then
        begin
          LastIdentity := '';
          Continue;
        end;
        NamePtr := nil;
        IdPtr := nil;
        Handle := 0;
        ControlType := 0;
        IsPassword := False;
        if Succeeded(Element.get_CurrentName(NamePtr)) and (NamePtr <> nil) then
        begin
          Name := NamePtr;
          SysFreeString(NamePtr);
        end
        else
          Name := '';
        if Succeeded(Element.get_CurrentAutomationId(IdPtr)) and (IdPtr <> nil) then
        begin
          AutomationId := IdPtr;
          SysFreeString(IdPtr);
        end
        else
          AutomationId := '';
        Element.get_CurrentNativeWindowHandle(Handle);
        Element.get_CurrentControlType(ControlType);
        Element.get_CurrentIsPassword(IsPassword);
        Identity := IntToStr(Handle) + '|' + AutomationId + '|' + Name + '|' +
          IntToStr(ControlType);
        if Identity = LastIdentity then
          Continue;
        LastIdentity := Identity;
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
        if Entered and not Terminated then
          Report(Kind);
      except
        LastIdentity := '';
      end;
    end;
  finally
    Client := nil;
    Element := nil;
    if (Init = S_OK) or (Init = S_FALSE) then
      CoUninitialize;
  end;
end;

end.
