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
    FMnuSoundRU: TMenuItem;
    FMnuSoundSwitch: TMenuItem;
    FMnuDoubleLShift: TMenuItem;
    FMnuSelectionLayout: TMenuItem;
    FMnuAutoStart: TMenuItem;
    FMnuHintTimed: TMenuItem;
    FMnuHintFollow: TMenuItem;
    FMnuHintOff: TMenuItem;
    FMnuHintFlash: TMenuItem;
    FMnuHintAnimate: TMenuItem;
    FCaretHintArmed: Boolean;
    FMnuCurrentApp: TMenuItem;
    FMnuCurrentAppRule: TMenuItem;
    FMnuExcludeCurrentApp: TMenuItem;
    FMnuModeCautious: TMenuItem;
    FMnuModeBalanced: TMenuItem;
    FMnuModeAggressive: TMenuItem;
    FMnuResetLearning: TMenuItem;
    FMnuDiagOff: TMenuItem;
    FMnuDiagError: TMenuItem;
    FMnuDiagInfo: TMenuItem;
    FMnuDiagVerbose: TMenuItem;
    FMnuResetDiagnostics: TMenuItem;
    FMnuOpenConfig: TMenuItem;
    FMnuExit: TMenuItem;
    FMnuSettings: TMenuItem;
    FMnuPause: TMenuItem;

    procedure CreateComponents;
    procedure CreateTrayMenu;
    function AddMenuItem(const ACaption: string; AOnClick: TNotifyEvent): TMenuItem;
    procedure SaveSettings;
    procedure OnLangChanged(ALang: TLangKind);
    procedure OnTimerTick(Sender: TObject);
    procedure UpdateMenuItems;
    procedure PopupMenuPopup(Sender: TObject);

    procedure mnuAutoSwitchClick(Sender: TObject);
    procedure mnuPauseClick(Sender: TObject);
    procedure mnuSoundRUClick(Sender: TObject);
    procedure mnuSoundSwitchClick(Sender: TObject);
    procedure mnuDoubleLShiftClick(Sender: TObject);
    procedure mnuSelectionLayoutClick(Sender: TObject);
    procedure mnuAutoStartClick(Sender: TObject);
    procedure mnuHintModeClick(Sender: TObject);
    procedure mnuHintFlashClick(Sender: TObject);
    procedure mnuHintAnimateClick(Sender: TObject);
    procedure mnuCurrentAppClick(Sender: TObject);
    procedure mnuCurrentAppRuleClick(Sender: TObject);
    procedure mnuExcludeCurrentAppClick(Sender: TObject);
    procedure mnuModeClick(Sender: TObject);
    procedure mnuResetLearningClick(Sender: TObject);
    procedure mnuDiagnosticsClick(Sender: TObject);
    procedure mnuResetDiagnosticsClick(Sender: TObject);
    procedure mnuOpenConfigClick(Sender: TObject);
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
  except
    on E: Exception do
      LogDiagnostic(dlError, deTimerFailure, E.HelpContext);
  end;
end;

procedure TfrmApp.CreateTrayMenu;
begin
  FPopupMenu.Items.Clear;

  FMnuSettings := AddMenuItem('Настройки', mnuSettingsClick);
  FMnuPause := AddMenuItem('Пауза', mnuPauseClick);
  AddMenuItem('-', nil);
  FMnuAutoSwitch := AddMenuItem('Автопереключение', mnuAutoSwitchClick);
  FMnuSoundRU := AddMenuItem('Звук при вводе в RU', mnuSoundRUClick);
  FMnuSoundSwitch := AddMenuItem('Звук при переключении', mnuSoundSwitchClick);
  FMnuDoubleLShift := AddMenuItem('Двойной Left Shift', mnuDoubleLShiftClick);
  FMnuSelectionLayout := AddMenuItem(
    'Менять раскладку после конвертации выделения', mnuSelectionLayoutClick);
  AddMenuItem('-', nil);
  FMnuCurrentApp := AddMenuItem('Временно отключить для текущего приложения',
    mnuCurrentAppClick);
  FMnuCurrentAppRule := AddMenuItem(
    'Автопереключение для текущего приложения', mnuCurrentAppRuleClick);
  FMnuExcludeCurrentApp := AddMenuItem(
    'Добавить текущее приложение в исключения', mnuExcludeCurrentAppClick);
  AddMenuItem('-', nil);
  FMnuModeCautious := AddMenuItem('Режим: осторожный', mnuModeClick);
  FMnuModeCautious.Tag := Integer(hmCautious);
  FMnuModeCautious.AutoCheck := False;
  FMnuModeBalanced := AddMenuItem('Режим: сбалансированный', mnuModeClick);
  FMnuModeBalanced.Tag := Integer(hmBalanced);
  FMnuModeAggressive := AddMenuItem('Режим: агрессивный', mnuModeClick);
  FMnuModeAggressive.Tag := Integer(hmAggressive);
  FMnuResetLearning := AddMenuItem('Сбросить обучение', mnuResetLearningClick);
  AddMenuItem('-', nil);
  FMnuHintTimed := AddMenuItem('Подсказка у каретки: на время', mnuHintModeClick);
  FMnuHintTimed.Tag := Ord(chTimed);
  FMnuHintFollow := AddMenuItem('Подсказка у каретки: следовать', mnuHintModeClick);
  FMnuHintFollow.Tag := Ord(chFollow);
  FMnuHintOff := AddMenuItem('Подсказка у каретки: не показывать', mnuHintModeClick);
  FMnuHintOff.Tag := Ord(chOff);
  FMnuHintFlash := AddMenuItem('Подсказка: вспышка при появлении', mnuHintFlashClick);
  FMnuHintAnimate := AddMenuItem('Подсказка: анимация размера', mnuHintAnimateClick);
  AddMenuItem('-', nil);
  FMnuDiagOff := AddMenuItem('Диагностика: выкл.', mnuDiagnosticsClick);
  FMnuDiagOff.Tag := Integer(dlOff);
  FMnuDiagError := AddMenuItem('Диагностика: ошибки', mnuDiagnosticsClick);
  FMnuDiagError.Tag := Integer(dlError);
  FMnuDiagInfo := AddMenuItem('Диагностика: информация', mnuDiagnosticsClick);
  FMnuDiagInfo.Tag := Integer(dlInfo);
  FMnuDiagVerbose := AddMenuItem('Диагностика: подробно', mnuDiagnosticsClick);
  FMnuDiagVerbose.Tag := Integer(dlVerbose);
  FMnuResetDiagnostics := AddMenuItem('Очистить диагностику',
    mnuResetDiagnosticsClick);
  FMnuAutoStart := AddMenuItem('Автозапуск', mnuAutoStartClick);
  AddMenuItem('-', nil);
  FMnuOpenConfig := AddMenuItem('Открыть config.json', mnuOpenConfigClick);
  AddMenuItem('-', nil);
  FMnuExit := AddMenuItem('Выход', mnuExitClick);
end;

procedure TfrmApp.OnLangChanged(ALang: TLangKind);
begin
  try
    UpdateTrayIconLang(FTrayIcon, ALang);
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
  if FMnuSoundRU <> nil then FMnuSoundRU.Checked := AppSettings.SoundOnRussianInput;
  if FMnuSoundSwitch <> nil then FMnuSoundSwitch.Checked := AppSettings.SoundOnSwitch;
  if FMnuDoubleLShift <> nil then FMnuDoubleLShift.Checked := AppSettings.DoubleLeftShiftEnabled;
  if FMnuSelectionLayout <> nil then
    FMnuSelectionLayout.Checked := AppSettings.SwitchLayoutAfterSelection;
  if FMnuAutoStart <> nil then FMnuAutoStart.Checked := AppSettings.AutoStart;
  if (HookManager <> nil) and (FMnuCurrentApp <> nil) then
    FMnuCurrentApp.Checked := HookManager.IsCurrentApplicationDisabled;
  if (HookManager <> nil) and (FMnuCurrentAppRule <> nil) then
    FMnuCurrentAppRule.Checked := HookManager.IsCurrentApplicationAutoSwitchEnabled;
  if FMnuModeCautious <> nil then
    FMnuModeCautious.Checked := AppSettings.HeuristicMode = hmCautious;
  if FMnuModeBalanced <> nil then
    FMnuModeBalanced.Checked := AppSettings.HeuristicMode = hmBalanced;
  if FMnuModeAggressive <> nil then
    FMnuModeAggressive.Checked := AppSettings.HeuristicMode = hmAggressive;
  if FMnuHintTimed <> nil then
    FMnuHintTimed.Checked := AppSettings.CaretHintMode = chTimed;
  if FMnuHintFollow <> nil then
    FMnuHintFollow.Checked := AppSettings.CaretHintMode = chFollow;
  if FMnuHintOff <> nil then
    FMnuHintOff.Checked := AppSettings.CaretHintMode = chOff;
  if FMnuHintFlash <> nil then
    FMnuHintFlash.Checked := AppSettings.CaretHintFlash;
  if FMnuHintAnimate <> nil then
    FMnuHintAnimate.Checked := AppSettings.CaretHintAnimate;
  if FMnuDiagOff <> nil then
    FMnuDiagOff.Checked := AppSettings.DiagnosticsLevel = dlOff;
  if FMnuDiagError <> nil then
    FMnuDiagError.Checked := AppSettings.DiagnosticsLevel = dlError;
  if FMnuDiagInfo <> nil then
    FMnuDiagInfo.Checked := AppSettings.DiagnosticsLevel = dlInfo;
  if FMnuDiagVerbose <> nil then
    FMnuDiagVerbose.Checked := AppSettings.DiagnosticsLevel = dlVerbose;
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

procedure TfrmApp.mnuSoundRUClick(Sender: TObject);
begin
  AppSettings.SoundOnRussianInput := not AppSettings.SoundOnRussianInput;
  SaveSettings;
end;

procedure TfrmApp.mnuSoundSwitchClick(Sender: TObject);
begin
  AppSettings.SoundOnSwitch := not AppSettings.SoundOnSwitch;
  SaveSettings;
end;

procedure TfrmApp.mnuDoubleLShiftClick(Sender: TObject);
begin
  AppSettings.DoubleLeftShiftEnabled := not AppSettings.DoubleLeftShiftEnabled;
  SaveSettings;
end;

procedure TfrmApp.mnuSelectionLayoutClick(Sender: TObject);
begin
  AppSettings.SwitchLayoutAfterSelection :=
    not AppSettings.SwitchLayoutAfterSelection;
  SaveSettings;
end;

procedure TfrmApp.mnuAutoStartClick(Sender: TObject);
begin
  AppSettings.AutoStart := not AppSettings.AutoStart;
  AppSettings.SaveToFile;
  ApplyAutoStart(AppSettings.AutoStart);
  UpdateMenuItems;
end;

procedure TfrmApp.mnuHintModeClick(Sender: TObject);
begin
  AppSettings.CaretHintMode := TCaretHintMode((Sender as TMenuItem).Tag);
  SaveSettings;
end;

procedure TfrmApp.mnuHintFlashClick(Sender: TObject);
begin
  AppSettings.CaretHintFlash := not AppSettings.CaretHintFlash;
  SaveSettings;
end;

procedure TfrmApp.mnuHintAnimateClick(Sender: TObject);
begin
  AppSettings.CaretHintAnimate := not AppSettings.CaretHintAnimate;
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

procedure TfrmApp.mnuModeClick(Sender: TObject);
begin
  AppSettings.HeuristicMode := THeuristicMode((Sender as TMenuItem).Tag);
  SaveSettings;
end;

procedure TfrmApp.mnuResetLearningClick(Sender: TObject);
begin
  AppSettings.ResetLearning;
  SaveSettings;
end;

procedure TfrmApp.mnuDiagnosticsClick(Sender: TObject);
begin
  AppSettings.DiagnosticsLevel :=
    TDiagnosticsLevel((Sender as TMenuItem).Tag);
  ConfigureDiagnostics(TPath.Combine(ExtractFilePath(ParamStr(0)),
    'diagnostics.log'), AppSettings.DiagnosticsLevel);
  SaveSettings;
end;

procedure TfrmApp.mnuResetDiagnosticsClick(Sender: TObject);
begin
  ResetDiagnostics;
end;

procedure TfrmApp.mnuOpenConfigClick(Sender: TObject);
begin
  ShellExecute(
    0,
    'open',
    PChar(AppSettings.ConfigFilePath),
    nil,
    nil,
    SW_SHOWNORMAL
  );
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
