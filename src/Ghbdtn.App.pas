unit Ghbdtn.App;

interface

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Vcl.Forms,
  Vcl.Menus,
  Vcl.ExtCtrls,
  Ghbdtn.Layout,
  Ghbdtn.TrayIcon,
  Ghbdtn.Analyzer,
  Ghbdtn.Diagnostics,
  Ghbdtn.Settings,
  Ghbdtn.Sound,
  Ghbdtn.AutoStart,
  Ghbdtn.CaretHint,
  Ghbdtn.Translit,
  Ghbdtn.SettingsForm,
  Ghbdtn.Hook{$IFDEF GHBDTN_UPDATE},
  Ghbdtn.Update{$ENDIF};

type
  TfrmApp = class(TForm)
  private
    FTrayIcon: TTrayIcon;
    FPopupMenu: TPopupMenu;
    FTimer: TTimer;
    FMnuAutoSwitch: TMenuItem;
    FCaretHintArmed: Boolean;
    FMnuExit: TMenuItem;
    FMnuCurrentApp: TMenuItem;
    FMnuCurrentAppRule: TMenuItem;
    FMnuApplication: TMenuItem;
    FMnuExcludeItem: TMenuItem;
    FMnuSelection: TMenuItem;
    FMnuSettings: TMenuItem;
    FMnuPause: TMenuItem;
    FMnuCase: TMenuItem;
    FMnuTranslit: TMenuItem;
    FMnuPauseFor: TMenuItem;
    FBaseHint: string;
    FShownPause: Integer;
    FTrayLang: TLangKind;
    FTrayPaused: Boolean;

    procedure CreateComponents;
    procedure CreateTrayMenu;
    function AddMenuItem(const ACaption: string; AOnClick: TNotifyEvent): TMenuItem;
    procedure AddCaseItem(const ACaption: string; AMode: TCaseMode);
    procedure AddPauseItem(const ACaption: string; AMinutes: Integer);
    procedure mnuPauseForClick(Sender: TObject);
    procedure RefreshPauseIndicators;
    procedure mnuCaseClick(Sender: TObject);
    procedure AddTranslitItem(const ACaption: string;
      ADirection: TTranslitDirection);
    procedure mnuTranslitClick(Sender: TObject);
    procedure SaveSettings;
    procedure OnLangChanged(ALang: TLangKind);
    procedure OnTimerTick(Sender: TObject);
    procedure UpdateMenuItems;
    procedure PopupMenuPopup(Sender: TObject);

    procedure mnuAutoSwitchClick(Sender: TObject);
    procedure mnuPauseClick(Sender: TObject);
    procedure mnuCurrentAppClick(Sender: TObject);
    procedure mnuCurrentAppRuleClick(Sender: TObject);
    procedure mnuExcludeCurrentAppClick(Sender: TObject);
    procedure mnuSettingsClick(Sender: TObject);
    procedure mnuExitClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  frmApp: TfrmApp;

implementation

constructor TfrmApp.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'Ghbdtn';
  Visible := False;

  CreateComponents;
  AppSettings.LoadFromFile;
  ConfigureDiagnostics(TPath.Combine(ExtractFilePath(ParamStr(0)),
    'diagnostics.log'), AppSettings.DiagnosticsLevel);
  InitializeSound;
  ApplyAutoStart(AppSettings.AutoStart);

  CreateTrayMenu;
  UpdateMenuItems;

  HookManager := TKbdHookManager.Create;
  HookManager.OnLangChange := OnLangChanged;
  try
    HookManager.StartHook;
  except
    on E: Exception do
    begin
      Application.MessageBox(PChar(E.Message), 'Ghbdtn',
        MB_OK or MB_ICONERROR);
      raise;
    end;
  end;

  // Fast timer (150 ms) tracks the foreground window and layout changes.
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 150;
  FTimer.OnTimer := OnTimerTick;
  FTimer.Enabled := True;

  // Initial layout icon.
  OnLangChanged(GetForegroundLangKind);
{$IFDEF GHBDTN_UPDATE}
  if UpdateCheckRequested then
    StartUpdateCheck;
{$ENDIF}
end;

destructor TfrmApp.Destroy;
begin
{$IFDEF GHBDTN_UPDATE}
  CancelUpdateCheck;
{$ENDIF}
  if HookManager <> nil then
  begin
    HookManager.StopHook;
    FreeAndNil(HookManager);
  end;
  ShutdownSound;
  inherited Destroy;
end;

procedure TfrmApp.CreateComponents;
begin
  FPopupMenu := TPopupMenu.Create(Self);
  FPopupMenu.OnPopup := PopupMenuPopup;
  FTrayIcon := TTrayIcon.Create(Self);
  FTrayIcon.PopupMenu := FPopupMenu;
end;

function TfrmApp.AddMenuItem(
  const ACaption: string;
  AOnClick: TNotifyEvent
): TMenuItem;
begin
  Result := TMenuItem.Create(FPopupMenu);
  Result.Caption := ACaption;
  Result.OnClick := AOnClick;
  FPopupMenu.Items.Add(Result);
end;

procedure TfrmApp.AddCaseItem(const ACaption: string; AMode: TCaseMode);
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(FPopupMenu);
  Item.Caption := ACaption;
  Item.Tag := Ord(AMode);
  Item.OnClick := mnuCaseClick;
  FMnuCase.Add(Item);
end;

procedure TfrmApp.mnuCaseClick(Sender: TObject);
begin
  if HookManager <> nil then
    HookManager.RunCaseCommand(TCaseMode(TMenuItem(Sender).Tag));
end;

procedure TfrmApp.AddPauseItem(const ACaption: string; AMinutes: Integer);
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(FPopupMenu);
  Item.Caption := ACaption;
  Item.Tag := AMinutes;
  Item.OnClick := mnuPauseForClick;
  FMnuPauseFor.Add(Item);
end;

procedure TfrmApp.mnuPauseForClick(Sender: TObject);
begin
  if HookManager <> nil then
    HookManager.PauseForMinutes(TMenuItem(Sender).Tag);
  RefreshPauseIndicators;
  UpdateMenuItems;
end;

{ The menu item and the tray tooltip show how long a timed pause still lasts. }
procedure TfrmApp.RefreshPauseIndicators;
var
  Remaining: Integer;
  Suffix: string;
begin
  if HookManager = nil then
    Exit;
  Remaining := HookManager.PauseMinutesRemaining;
  if Remaining = FShownPause then
    Exit;
  FShownPause := Remaining;
  if (Remaining <> 0) <> FTrayPaused then
  begin
    FTrayPaused := Remaining <> 0;
    if FBaseHint <> '' then
    begin
      UpdateTrayIconLang(FTrayIcon, FTrayLang, FTrayPaused);
      FBaseHint := FTrayIcon.Hint;
    end;
  end;
  if Remaining > 0 then
    Suffix := ' - пауза, осталось ' + IntToStr(Remaining) + ' мин'
  else if Remaining < 0 then
    Suffix := ' - пауза'
  else
    Suffix := '';
  if FBaseHint <> '' then
    FTrayIcon.Hint := FBaseHint + Suffix;
  if FMnuPause <> nil then
  begin
    if Remaining > 0 then
      FMnuPause.Caption := 'Пауза (осталось ' + IntToStr(Remaining) + ' мин)'
    else
      FMnuPause.Caption := 'Пауза';
  end;
end;

procedure TfrmApp.AddTranslitItem(const ACaption: string;
  ADirection: TTranslitDirection);
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(FPopupMenu);
  Item.Caption := ACaption;
  Item.Tag := Ord(ADirection);
  Item.OnClick := mnuTranslitClick;
  FMnuTranslit.Add(Item);
end;

procedure TfrmApp.mnuTranslitClick(Sender: TObject);
begin
  if HookManager <> nil then
    HookManager.RunTranslitCommand(TTranslitDirection(TMenuItem(Sender).Tag));
end;

procedure TfrmApp.SaveSettings;
begin
  AppSettings.SaveToFile;
  UpdateMenuItems;
end;

procedure TfrmApp.OnTimerTick(Sender: TObject);
begin
  try
    if HookManager <> nil then
      HookManager.CheckLangChange;
    RefreshPauseIndicators;
  except
    on E: Exception do
      LogDiagnostic(dlError, deTimerFailure, E.HelpContext);
  end;
end;

procedure TfrmApp.CreateTrayMenu;
begin
  FPopupMenu.Items.Clear;

  FMnuAutoSwitch := AddMenuItem('Автопереключение', mnuAutoSwitchClick);
  FMnuPause := AddMenuItem('Пауза', mnuPauseClick);
  FMnuPauseFor := AddMenuItem('Пауза на время', nil);
  AddPauseItem('На 30 минут', 30);
  AddPauseItem('На 1 час', 60);
  AddPauseItem('До перезапуска', 0);
  FMnuSelection := AddMenuItem('Выделение или слово', nil);
  FMnuCase := FMnuSelection;
  FMnuTranslit := FMnuSelection;
  AddCaseItem('ВЕРХНИЙ РЕГИСТР', cmUpper);
  AddCaseItem('нижний регистр', cmLower);
  AddCaseItem('Первая заглавная', cmCapitalize);
  AddCaseItem('иНВЕРСИЯ РЕГИСТРА', cmInvert);
  FMnuSelection.Add(NewLine);
  AddTranslitItem('В транслит (привет -> privet)', tdToLatin);
  AddTranslitItem('Из транслита (privet -> привет)', tdToCyrillic);
  AddMenuItem('-', nil);
  FMnuApplication := AddMenuItem('Текущее приложение', nil);
  FMnuCurrentApp := TMenuItem.Create(FPopupMenu);
  FMnuCurrentApp.Caption := 'Временно отключить';
  FMnuCurrentApp.OnClick := mnuCurrentAppClick;
  FMnuApplication.Add(FMnuCurrentApp);
  FMnuCurrentAppRule := TMenuItem.Create(FPopupMenu);
  FMnuCurrentAppRule.Caption := 'Автопереключение включено';
  FMnuCurrentAppRule.OnClick := mnuCurrentAppRuleClick;
  FMnuApplication.Add(FMnuCurrentAppRule);
  FMnuApplication.Add(NewLine);
  FMnuExcludeItem := TMenuItem.Create(FPopupMenu);
  FMnuExcludeItem.Caption := 'Добавить в исключения';
  FMnuExcludeItem.OnClick := mnuExcludeCurrentAppClick;
  FMnuApplication.Add(FMnuExcludeItem);
  AddMenuItem('-', nil);
  FMnuSettings := AddMenuItem('Настройки...', mnuSettingsClick);
  AddMenuItem('-', nil);
  FMnuExit := AddMenuItem('Выход', mnuExitClick);
end;

procedure TfrmApp.OnLangChanged(ALang: TLangKind);
begin
  try
    FTrayLang := ALang;
    UpdateTrayIconLang(FTrayIcon, ALang, FTrayPaused);
    FBaseHint := FTrayIcon.Hint;
    FShownPause := -2;
    RefreshPauseIndicators;
    if FCaretHintArmed then
      ShowCaretHint(ALang)
    else
      FCaretHintArmed := True;
  except
    on E: Exception do
      LogDiagnostic(dlError, deTrayUpdateFailed, E.HelpContext);
  end;
end;

procedure TfrmApp.UpdateMenuItems;
begin
  if FMnuPause <> nil then
    FMnuPause.Checked := (HookManager <> nil) and HookManager.IsGloballyPaused;
  if FMnuAutoSwitch <> nil then FMnuAutoSwitch.Checked := AppSettings.AutoSwitchEnabled;
  if (HookManager <> nil) and (FMnuCurrentApp <> nil) then
    FMnuCurrentApp.Checked := HookManager.IsCurrentApplicationDisabled;
  if (HookManager <> nil) and (FMnuCurrentAppRule <> nil) then
    FMnuCurrentAppRule.Checked := HookManager.IsCurrentApplicationAutoSwitchEnabled;
end;

procedure TfrmApp.PopupMenuPopup(Sender: TObject);
begin
  UpdateMenuItems;
end;

procedure TfrmApp.mnuPauseClick(Sender: TObject);
begin
  if HookManager <> nil then
    HookManager.ToggleGlobalPause;
  UpdateMenuItems;
end;

procedure TfrmApp.mnuAutoSwitchClick(Sender: TObject);
begin
  AppSettings.AutoSwitchEnabled := not AppSettings.AutoSwitchEnabled;
  SaveSettings;
end;

procedure TfrmApp.mnuCurrentAppClick(Sender: TObject);
begin
  if HookManager <> nil then
    HookManager.ToggleCurrentApplicationDisabled;
  UpdateMenuItems;
end;

procedure TfrmApp.mnuCurrentAppRuleClick(Sender: TObject);
begin
  if HookManager <> nil then
    HookManager.ToggleCurrentApplicationRule;
  UpdateMenuItems;
end;

procedure TfrmApp.mnuExcludeCurrentAppClick(Sender: TObject);
begin
  if HookManager <> nil then
    HookManager.AddCurrentApplicationToExclusions;
  UpdateMenuItems;
end;

procedure TfrmApp.mnuSettingsClick(Sender: TObject);
begin
  if EditAppSettings then
    UpdateMenuItems;
end;

procedure TfrmApp.mnuExitClick(Sender: TObject);
begin
  Application.Terminate;
end;

end.
