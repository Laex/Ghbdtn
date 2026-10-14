unit Ghbdtn.SettingsForm;

interface

function EditAppSettings: Boolean;

implementation

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Math,
  System.IOUtils,
  System.UITypes,
  System.Generics.Collections,
  Vcl.Graphics,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Dialogs,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  Ghbdtn.Analyzer,
  Ghbdtn.Diagnostics,
  Ghbdtn.Learning,
  Ghbdtn.Settings,
  Ghbdtn.AutoStart,
  Ghbdtn.Hook;

type
  TLearningRow = class
    Process: string;
    Word: string;
  end;

  TPatternRow = class
    Pattern: string;
  end;

  TExclusionDialog = class
  private
    FList: TListBox;
    FPattern: TEdit;
    FDelete: TButton;
    procedure Reload;
    procedure AddClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
  public
    procedure Show;
  end;

  TRuleDialog = class
  private
    FList: TListBox;
    FPattern: TEdit;
    FAutoOverride: TCheckBox;
    FAutoValue: TCheckBox;
    FInputOverride: TCheckBox;
    FInputValue: TCheckBox;
    FSwitchOverride: TCheckBox;
    FSwitchValue: TCheckBox;
    FModeOverride: TCheckBox;
    FMode: TRadioGroup;
    FDelete: TButton;
    procedure FreeRows;
    procedure Reload;
    procedure SelectClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
  public
    procedure Show;
  end;

  TLearningListDialog = class
  private
    FForm: TForm;
    FList: TListBox;
    FDelete: TButton;
    FWord: TEdit;
    FProcess: TEdit;
    procedure FreeRows;
    procedure Reload;
    procedure DeleteClick(Sender: TObject);
    procedure SelectClick(Sender: TObject);
    procedure AddClick(Sender: TObject);
  public
    procedure Show;
  end;

function LearningPlace(const AProcess: string): string;
begin
  if (AProcess = '') or (AProcess = AllApplicationsLearning) then
    Result := 'все приложения'
  else
    Result := AProcess;
end;

function LearningEffect(const AItem: TLearningView): string;
begin
  if AItem.Process = '' then
    Result := 'не действует'
  else if AItem.Forces then
    Result := 'переключать'
  else if AItem.Blocks then
    Result := 'не переключать'
  else
    Result := 'ещё не действует';
end;

procedure TLearningListDialog.FreeRows;
var
  I: Integer;
begin
  for I := 0 to FList.Count - 1 do
    FList.Items.Objects[I].Free;
end;

procedure TLearningListDialog.Reload;
var
  Item: TLearningView;
  Row: TLearningRow;
begin
  FList.Items.BeginUpdate;
  try
    FreeRows;
    FList.Clear;
    for Item in AppSettings.ListLearning do
    begin
      Row := TLearningRow.Create;
      Row.Process := Item.Process;
      Row.Word := Item.Word;
      FList.Items.AddObject(LearningPlace(Item.Process) + '  —  ' + Item.Word +
        '  —  ' + LearningEffect(Item), Row);
    end;
  finally
    FList.Items.EndUpdate;
  end;
  FDelete.Enabled := FList.Count > 0;
  if FList.Count > 0 then
    FList.ItemIndex := 0;
end;

procedure TLearningListDialog.DeleteClick(Sender: TObject);
var
  Row: TLearningRow;
begin
  if FList.ItemIndex < 0 then
    Exit;
  Row := TLearningRow(FList.Items.Objects[FList.ItemIndex]);
  AppSettings.ForgetLearning(Row.Process, Row.Word);
  AppSettings.SaveToFile;
  Reload;
end;

procedure TLearningListDialog.SelectClick(Sender: TObject);
begin
  FDelete.Enabled := FList.ItemIndex >= 0;
end;

procedure TLearningListDialog.AddClick(Sender: TObject);
var
  Process: string;
begin
  Process := Trim(FProcess.Text);
  AppSettings.PinLearning(Trim(FWord.Text), Process, TButton(Sender).Tag = 1);
  AppSettings.SaveToFile;
  Reload;
end;

procedure TLearningListDialog.Show;
var
  CloseButton, NeverButton, PreferButton: TButton;
  WordLabel, ProcessLabel, HintLabel: TLabel;
begin
  FForm := TForm.CreateNew(nil);
  try
    FForm.Caption := 'Обучение';
    FForm.BorderStyle := bsDialog;
    FForm.Position := poScreenCenter;
    FForm.ClientWidth := 560;
    FForm.ClientHeight := 468;
    FForm.Font.Name := 'Segoe UI';
    FForm.Font.Height := -12;

    FList := TListBox.Create(FForm);
    FList.Parent := FForm;
    FList.SetBounds(16, 16, 528, 248);
    FList.OnClick := SelectClick;

    WordLabel := TLabel.Create(FForm);
    WordLabel.Parent := FForm;
    WordLabel.Caption := 'Слово';
    WordLabel.SetBounds(16, 274, 80, 16);

    FWord := TEdit.Create(FForm);
    FWord.Parent := FForm;
    FWord.SetBounds(100, 270, 444, 24);

    ProcessLabel := TLabel.Create(FForm);
    ProcessLabel.Parent := FForm;
    ProcessLabel.Caption := 'Приложение';
    ProcessLabel.SetBounds(16, 306, 80, 16);

    FProcess := TEdit.Create(FForm);
    FProcess.Parent := FForm;
    FProcess.SetBounds(100, 302, 444, 24);
    if HookManager <> nil then
      FProcess.Text := HookManager.CurrentLearningProcess;

    HintLabel := TLabel.Create(FForm);
    HintLabel.Parent := FForm;
    HintLabel.Caption := 'Пустое приложение действует во всех, где нет своей записи';
    HintLabel.SetBounds(100, 330, 444, 16);

    NeverButton := TButton.Create(FForm);
    NeverButton.Parent := FForm;
    NeverButton.Caption := 'Не переключать';
    NeverButton.SetBounds(16, 356, 140, 28);
    NeverButton.Tag := 0;
    NeverButton.OnClick := AddClick;

    PreferButton := TButton.Create(FForm);
    PreferButton.Parent := FForm;
    PreferButton.Caption := 'Переключать';
    PreferButton.SetBounds(164, 356, 120, 28);
    PreferButton.Tag := 1;
    PreferButton.OnClick := AddClick;

    FDelete := TButton.Create(FForm);
    FDelete.Parent := FForm;
    FDelete.Caption := 'Удалить';
    FDelete.SetBounds(16, 424, 100, 28);
    FDelete.OnClick := DeleteClick;

    CloseButton := TButton.Create(FForm);
    CloseButton.Parent := FForm;
    CloseButton.Caption := 'Закрыть';
    CloseButton.SetBounds(444, 424, 100, 28);
    CloseButton.Cancel := True;
    CloseButton.ModalResult := mrClose;

    Reload;
    FForm.ShowModal;
    FreeRows;
  finally
    FForm.Free;
  end;
end;

procedure TExclusionDialog.Reload;
var
  Item: string;
begin
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    for Item in AppSettings.ListExclusions do
      FList.Items.Add(Item);
  finally
    FList.Items.EndUpdate;
  end;
  FDelete.Enabled := FList.Count > 0;
  if FList.Count > 0 then
    FList.ItemIndex := 0;
end;

procedure TExclusionDialog.AddClick(Sender: TObject);
begin
  AppSettings.AddExclusion(Trim(FPattern.Text));
  AppSettings.SaveToFile;
  FPattern.Text := '';
  Reload;
end;

procedure TExclusionDialog.DeleteClick(Sender: TObject);
begin
  if FList.ItemIndex < 0 then
    Exit;
  AppSettings.RemoveExclusion(FList.Items[FList.ItemIndex]);
  AppSettings.SaveToFile;
  Reload;
end;

procedure TExclusionDialog.Show;
var
  Form: TForm;
  AddButton, CloseButton: TButton;
begin
  Form := TForm.CreateNew(nil);
  try
    Form.Caption := 'Исключения';
    Form.BorderStyle := bsDialog;
    Form.Position := poScreenCenter;
    Form.ClientWidth := 420;
    Form.ClientHeight := 360;
    Form.Font.Name := 'Segoe UI';
    Form.Font.Height := -12;

    FList := TListBox.Create(Form);
    FList.Parent := Form;
    FList.SetBounds(16, 16, 388, 240);

    FPattern := TEdit.Create(Form);
    FPattern.Parent := Form;
    FPattern.SetBounds(16, 268, 388, 24);

    AddButton := TButton.Create(Form);
    AddButton.Parent := Form;
    AddButton.Caption := 'Добавить';
    AddButton.SetBounds(16, 308, 100, 28);
    AddButton.OnClick := AddClick;

    FDelete := TButton.Create(Form);
    FDelete.Parent := Form;
    FDelete.Caption := 'Удалить';
    FDelete.SetBounds(124, 308, 100, 28);
    FDelete.OnClick := DeleteClick;

    CloseButton := TButton.Create(Form);
    CloseButton.Parent := Form;
    CloseButton.Caption := 'Закрыть';
    CloseButton.SetBounds(304, 308, 100, 28);
    CloseButton.Cancel := True;
    CloseButton.ModalResult := mrClose;

    Reload;
    Form.ShowModal;
  finally
    Form.Free;
  end;
end;

procedure EditExclusions;
var
  Dialog: TExclusionDialog;
begin
  Dialog := TExclusionDialog.Create;
  try
    Dialog.Show;
  finally
    Dialog.Free;
  end;
end;

function ModeCaption(AMode: THeuristicMode): string;
begin
  case AMode of
    hmCautious: Result := 'осторожный';
    hmAggressive: Result := 'агрессивный';
  else
    Result := 'сбалансированный';
  end;
end;

function RuleSummary(const ARule: TApplicationRuleView): string;
begin
  Result := ARule.Pattern;
  if ARule.HasAutoSwitch then
  begin
    if ARule.AutoSwitchEnabled then
      Result := Result + ', авто'
    else
      Result := Result + ', без авто';
  end;
  if ARule.HasHeuristicMode then
    Result := Result + ', ' + ModeCaption(ARule.HeuristicMode);
end;

procedure TRuleDialog.FreeRows;
  var
    I: Integer;
  begin
    for I := 0 to FList.Count - 1 do
      FList.Items.Objects[I].Free;
  end;

procedure TRuleDialog.Reload;
  var
    Rule: TApplicationRuleView;
    Row: TPatternRow;
  begin
    FList.Items.BeginUpdate;
    try
      FreeRows;
      FList.Clear;
      for Rule in AppSettings.ListApplicationRules do
      begin
        Row := TPatternRow.Create;
        Row.Pattern := Rule.Pattern;
        FList.Items.AddObject(RuleSummary(Rule), Row);
      end;
    finally
      FList.Items.EndUpdate;
    end;
    FDelete.Enabled := FList.Count > 0;
    if FList.Count > 0 then
      FList.ItemIndex := 0;
end;

procedure TRuleDialog.SelectClick(Sender: TObject);
  var
    Rules: TArray<TApplicationRuleView>;
    Rule: TApplicationRuleView;
    Row: TPatternRow;
  begin
    FDelete.Enabled := FList.ItemIndex >= 0;
    if (FList.ItemIndex < 0) or (FList.Items.Objects[FList.ItemIndex] = nil) then
      Exit;
    Row := TPatternRow(FList.Items.Objects[FList.ItemIndex]);
    FPattern.Text := Row.Pattern;
    Rules := AppSettings.ListApplicationRules;
    for Rule in Rules do
      if SameText(Rule.Pattern, Row.Pattern) then
      begin
        FAutoOverride.Checked := Rule.HasAutoSwitch;
        FAutoValue.Checked := Rule.AutoSwitchEnabled;
        FInputOverride.Checked := Rule.HasSoundOnRussianInput;
        FInputValue.Checked := Rule.SoundOnRussianInput;
        FSwitchOverride.Checked := Rule.HasSoundOnSwitch;
        FSwitchValue.Checked := Rule.SoundOnSwitch;
        FModeOverride.Checked := Rule.HasHeuristicMode;
        FMode.ItemIndex := Ord(Rule.HeuristicMode);
        Break;
      end;
end;

procedure TRuleDialog.SaveClick(Sender: TObject);
  var
    Name: string;
  begin
    Name := Trim(FPattern.Text);
    if Name = '' then
      Exit;
    if FMode.ItemIndex < 0 then
      FMode.ItemIndex := Ord(hmBalanced);
    if not FAutoOverride.Checked and not FInputOverride.Checked and
       not FSwitchOverride.Checked and not FModeOverride.Checked then
      AppSettings.RemoveApplicationRule(Name)
    else
      AppSettings.SetApplicationRuleOverrides(Name,
        FAutoOverride.Checked, FAutoValue.Checked,
        FInputOverride.Checked, FInputValue.Checked,
        FSwitchOverride.Checked, FSwitchValue.Checked,
        FModeOverride.Checked, THeuristicMode(FMode.ItemIndex));
    AppSettings.SaveToFile;
    Reload;
end;

procedure TRuleDialog.DeleteClick(Sender: TObject);
  var
    Row: TPatternRow;
  begin
    if FList.ItemIndex < 0 then
      Exit;
    Row := TPatternRow(FList.Items.Objects[FList.ItemIndex]);
    AppSettings.RemoveApplicationRule(Row.Pattern);
    AppSettings.SaveToFile;
    Reload;
end;

procedure TRuleDialog.Show;
var
  Form: TForm;
  SaveButton, CloseButton: TButton;
begin
  Form := TForm.CreateNew(nil);
  try
    Form.Caption := 'Правила приложений';
    Form.BorderStyle := bsDialog;
    Form.Position := poScreenCenter;
    Form.ClientWidth := 460;
    Form.ClientHeight := 520;
    Form.Font.Name := 'Segoe UI';
    Form.Font.Height := -12;

    FList := TListBox.Create(Form);
    FList.Parent := Form;
    FList.SetBounds(16, 16, 428, 140);
    FList.OnClick := SelectClick;

    FPattern := TEdit.Create(Form);
    FPattern.Parent := Form;
    FPattern.SetBounds(16, 164, 428, 24);

    FAutoOverride := TCheckBox.Create(Form);
    FAutoOverride.Parent := Form;
    FAutoOverride.Caption := 'Своё автопереключение';
    FAutoOverride.SetBounds(16, 200, 220, 20);
    FAutoValue := TCheckBox.Create(Form);
    FAutoValue.Parent := Form;
    FAutoValue.Caption := 'Включено';
    FAutoValue.SetBounds(250, 200, 160, 20);

    FInputOverride := TCheckBox.Create(Form);
    FInputOverride.Parent := Form;
    FInputOverride.Caption := 'Свой звук ввода RU';
    FInputOverride.SetBounds(16, 228, 220, 20);
    FInputValue := TCheckBox.Create(Form);
    FInputValue.Parent := Form;
    FInputValue.Caption := 'Включено';
    FInputValue.SetBounds(250, 228, 160, 20);

    FSwitchOverride := TCheckBox.Create(Form);
    FSwitchOverride.Parent := Form;
    FSwitchOverride.Caption := 'Свой звук переключения';
    FSwitchOverride.SetBounds(16, 256, 220, 20);
    FSwitchValue := TCheckBox.Create(Form);
    FSwitchValue.Parent := Form;
    FSwitchValue.Caption := 'Включено';
    FSwitchValue.SetBounds(250, 256, 160, 20);

    FModeOverride := TCheckBox.Create(Form);
    FModeOverride.Parent := Form;
    FModeOverride.Caption := 'Свой режим эвристики';
    FModeOverride.SetBounds(16, 284, 220, 20);

    FMode := TRadioGroup.Create(Form);
    FMode.Parent := Form;
    FMode.Caption := 'Эвристика';
    FMode.SetBounds(16, 312, 428, 78);
    FMode.Items.Add('Осторожный');
    FMode.Items.Add('Сбалансированный');
    FMode.Items.Add('Агрессивный');
    FMode.ItemIndex := 1;

    SaveButton := TButton.Create(Form);
    SaveButton.Parent := Form;
    SaveButton.Caption := 'Сохранить';
    SaveButton.SetBounds(16, 476, 110, 28);
    SaveButton.OnClick := SaveClick;

    FDelete := TButton.Create(Form);
    FDelete.Parent := Form;
    FDelete.Caption := 'Удалить';
    FDelete.SetBounds(134, 476, 100, 28);
    FDelete.OnClick := DeleteClick;

    CloseButton := TButton.Create(Form);
    CloseButton.Parent := Form;
    CloseButton.Caption := 'Закрыть';
    CloseButton.SetBounds(344, 476, 100, 28);
    CloseButton.Cancel := True;
    CloseButton.ModalResult := mrClose;

    Reload;
    Form.ShowModal;
    FreeRows;
  finally
    Form.Free;
  end;
end;

procedure EditApplicationRules;
var
  Dialog: TRuleDialog;
begin
  Dialog := TRuleDialog.Create;
  try
    Dialog.Show;
  finally
    Dialog.Free;
  end;
end;

type
  // A flat on/off switch drawn with GDI+: a filled accent track with a white
  // thumb when on, an outlined track with a dark thumb when off.
  TSwitch = class(TCustomControl)
  private
    FOn: Boolean;
    FHot: Boolean;
    procedure SetOn(AValue: Boolean);
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
  protected
    procedure Paint; override;
    procedure Click; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    property Checked: Boolean read FOn write SetOn;
  end;

constructor TSwitch.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csOpaque] + [csSetCaption];
  TabStop := True;
  Cursor := crHandPoint;
  DoubleBuffered := True;
  Width := 46;
  Height := 24;
end;

procedure TSwitch.SetOn(AValue: Boolean);
begin
  if FOn = AValue then
    Exit;
  FOn := AValue;
  Invalidate;
end;

procedure TSwitch.Click;
begin
  if Enabled then
    SetOn(not FOn);
  inherited Click;
end;

procedure TSwitch.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if CanFocus then
    SetFocus;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TSwitch.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if Key = VK_SPACE then
  begin
    Click;
    Key := 0;
  end;
  inherited KeyDown(Key, Shift);
end;

procedure TSwitch.CMMouseEnter(var Message: TMessage);
begin
  FHot := True;
  Invalidate;
end;

procedure TSwitch.CMMouseLeave(var Message: TMessage);
begin
  FHot := False;
  Invalidate;
end;

procedure TSwitch.CMEnabledChanged(var Message: TMessage);
begin
  inherited;
  Invalidate;
end;

procedure TSwitch.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  Invalidate;
end;

procedure TSwitch.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  Invalidate;
end;

procedure TSwitch.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTARROWS;
end;

procedure TSwitch.Paint;
var
  G: TGPGraphics;
  Fill, Thumb: TGPSolidBrush;
  Pen: TGPPen;
  Path: TGPGraphicsPath;
  TrackW, TrackH, ThumbD, ThumbX, Pad: Single;
  Accent, Ink: Cardinal;

  procedure RoundTrack(X, Y, W, H: Single);
  begin
    Path.Reset;
    Path.AddArc(X, Y, H, H, 90, 180);
    Path.AddArc(X + W - H, Y, H, H, 270, 180);
    Path.CloseFigure;
  end;

begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  G := TGPGraphics.Create(Canvas.Handle);
  Path := TGPGraphicsPath.Create;
  try
    G.SetSmoothingMode(SmoothingModeAntiAlias);
    TrackW := Width - 3;
    TrackH := Height - 4;
    Pad := 1.5;
    Accent := MakeColor(255, 0, 103, 192);
    Ink := MakeColor(255, 90, 90, 90);
    if not Enabled then
    begin
      Accent := MakeColor(255, 160, 160, 160);
      Ink := MakeColor(255, 170, 170, 170);
    end
    else if FHot and not FOn then
      Ink := MakeColor(255, 32, 32, 32);
    RoundTrack(Pad, 2, TrackW, TrackH);
    if FOn then
    begin
      Fill := TGPSolidBrush.Create(Accent);
      try
        G.FillPath(Fill, Path);
      finally
        Fill.Free;
      end;
      ThumbD := TrackH - 8;
      ThumbX := Pad + TrackW - TrackH + 4;
      Thumb := TGPSolidBrush.Create(MakeColor(255, 255, 255, 255));
    end
    else
    begin
      Pen := TGPPen.Create(Ink, 1.5);
      try
        G.DrawPath(Pen, Path);
      finally
        Pen.Free;
      end;
      ThumbD := TrackH - 11;
      ThumbX := Pad + 5.5;
      Thumb := TGPSolidBrush.Create(Ink);
    end;
    try
      G.FillEllipse(Thumb, ThumbX, 2 + (TrackH - ThumbD) / 2, ThumbD, ThumbD);
    finally
      Thumb.Free;
    end;
    if Focused then
    begin
      Pen := TGPPen.Create(MakeColor(255, 0, 0, 0), 1);
      try
        Pen.SetDashStyle(DashStyleDot);
        G.DrawRectangle(Pen, 0.5, 0.5, Width - 2, Height - 2);
      finally
        Pen.Free;
      end;
    end;
  finally
    Path.Free;
    G.Free;
  end;
end;

const
  // Layout values are in pixels at 96 DPI and scaled by the form.
  PageMargin = 24;
  RowHeight = 36;
  SectionGap = 14;
  SectionHeight = 30;
  ComboWidth = 190;
  SwitchBoxWidth = 46;
  ButtonBarHeight = 56;

type
  TfrmSettings = class(TForm)
  private
    FDpi: Integer;
    FScroll: TScrollBox;
    FMainPanel: TPanel;
    FAdvancedPanel: TPanel;
    FSpoiler: TLabel;
    FBar: TPanel;
    FApplyButton: TButton;
    FAutoSwitch: TSwitch;
    FSoundRU: TSwitch;
    FSoundSwitch: TSwitch;
    FDoubleShift: TSwitch;
    FSelectionLayout: TSwitch;
    FAutoStart: TSwitch;
    FFixCaps: TSwitch;
    FFixCapsLock: TSwitch;
    FPauseFullscreen: TSwitch;
    FEnglishSecure: TSwitch;
    FDoubleCtrl: TSwitch;
    FEarlySwitch: TSwitch;
    FEarlyLetters: TComboBox;
    FHintFlash: TSwitch;
    FHintAnimate: TSwitch;
    FMode: TComboBox;
    FHintMode: TComboBox;
    FDiagnostics: TComboBox;
    FAdvancedShown: Boolean;
    function S(AValue: Integer): Integer;
    function AddSection(AParent: TWinControl; var AY: Integer;
      const ATitle: string): TLabel;
    function AddToggle(AParent: TWinControl; var AY: Integer;
      const ACaption: string): TSwitch;
    function AddCombo(AParent: TWinControl; var AY: Integer;
      const ACaption: string; const AItems: array of string): TComboBox;
    function AddButton(AParent: TWinControl; const ACaption: string;
      ALeft, ATop: Integer; AOnClick: TNotifyEvent): TButton;
    procedure BuildMain(var AY: Integer);
    procedure BuildAdvanced(var AY: Integer);
    procedure FitHeight;
    procedure SpoilerClick(Sender: TObject);
    procedure WheelScroll(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure ApplyClick(Sender: TObject);
    procedure OkClick(Sender: TObject);
    procedure LoadValues;
    procedure ApplyValues;
    procedure ResetLearningClick(Sender: TObject);
    procedure LearningListClick(Sender: TObject);
    procedure ExclusionsClick(Sender: TObject);
    procedure RulesClick(Sender: TObject);
    procedure ResetDiagnosticsClick(Sender: TObject);
    procedure OpenLogClick(Sender: TObject);
    procedure OpenConfigClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

function DiagnosticsLogPath: string;
begin
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'diagnostics.log');
end;

function TfrmSettings.S(AValue: Integer): Integer;
begin
  Result := MulDiv(AValue, FDpi, 96);
end;

function TfrmSettings.AddSection(AParent: TWinControl; var AY: Integer;
  const ATitle: string): TLabel;
begin
  Inc(AY, S(SectionGap));
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Caption := ATitle;
  Result.Font.Style := [fsBold];
  Result.Font.Size := 10;
  Result.Font.Color := TColor($9E5A00);
  Result.Left := S(PageMargin);
  Result.Top := AY;
  Inc(AY, S(SectionHeight));
end;

function TfrmSettings.AddToggle(AParent: TWinControl; var AY: Integer;
  const ACaption: string): TSwitch;
var
  Caption: TLabel;
begin
  Result := TSwitch.Create(Self);
  Result.Parent := AParent;
  Result.SetBounds(AParent.ClientWidth - S(PageMargin) - S(SwitchBoxWidth),
    AY + (S(RowHeight) - S(24)) div 2, S(SwitchBoxWidth), S(24));
  Result.Anchors := [akTop, akRight];
  Caption := TLabel.Create(Self);
  Caption.Parent := AParent;
  Caption.Caption := ACaption;
  Caption.AutoSize := False;
  Caption.WordWrap := True;
  Caption.Layout := tlCenter;
  Caption.SetBounds(S(PageMargin), AY,
    Result.Left - S(PageMargin) - S(12), S(RowHeight));
  Caption.Anchors := [akLeft, akTop, akRight];
  Caption.FocusControl := Result;
  Inc(AY, S(RowHeight));
end;

function TfrmSettings.AddCombo(AParent: TWinControl; var AY: Integer;
  const ACaption: string; const AItems: array of string): TComboBox;
var
  Caption: TLabel;
  Item: string;
begin
  Result := TComboBox.Create(Self);
  Result.Parent := AParent;
  Result.Style := csDropDownList;
  for Item in AItems do
    Result.Items.Add(Item);
  Result.SetBounds(AParent.ClientWidth - S(PageMargin) - S(ComboWidth),
    AY + (S(RowHeight) - Result.Height) div 2, S(ComboWidth), Result.Height);
  Result.Anchors := [akTop, akRight];
  Caption := TLabel.Create(Self);
  Caption.Parent := AParent;
  Caption.Caption := ACaption;
  Caption.AutoSize := False;
  Caption.Layout := tlCenter;
  Caption.SetBounds(S(PageMargin), AY,
    Result.Left - S(PageMargin) - S(12), S(RowHeight));
  Caption.Anchors := [akLeft, akTop, akRight];
  Caption.FocusControl := Result;
  Inc(AY, S(RowHeight));
end;

function TfrmSettings.AddButton(AParent: TWinControl; const ACaption: string;
  ALeft, ATop: Integer; AOnClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.OnClick := AOnClick;
  Result.Height := S(30);
  Result.Width := Max(S(96), Canvas.TextWidth(ACaption) + S(32));
  Result.Left := ALeft;
  Result.Top := ATop;
end;

procedure TfrmSettings.BuildMain(var AY: Integer);
begin
  AddSection(FMainPanel, AY, 'Основное');
  FAutoSwitch := AddToggle(FMainPanel, AY, 'Исправлять раскладку автоматически');
  FMode := AddCombo(FMainPanel, AY, 'Уверенность исправления',
    ['Осторожно', 'Сбалансированно', 'Агрессивно']);
  FAutoStart := AddToggle(FMainPanel, AY, 'Запускать вместе с Windows');

  AddSection(FMainPanel, AY, 'Исправления при наборе');
  FFixCaps := AddToggle(FMainPanel, AY,
    'Две заглавные в начале слова (ТОлько -> Только)');
  FFixCapsLock := AddToggle(FMainPanel, AY,
    'Слово с нажатым Caps Lock (пРИВЕТ -> Привет)');
  FEarlySwitch := AddToggle(FMainPanel, AY,
    'Переключать раскладку, не дожидаясь конца слова');
  FEarlyLetters := AddCombo(FMainPanel, AY, 'Букв до раннего переключения',
    ['3', '4', '5', '6', '7', '8']);
  FEnglishSecure := AddToggle(FMainPanel, AY,
    'Английская раскладка в полях пароля и e-mail');

  AddSection(FMainPanel, AY, 'Жесты');
  FDoubleShift := AddToggle(FMainPanel, AY,
    'Двойной Left Shift: конвертировать слово или выделение');
  FDoubleCtrl := AddToggle(FMainPanel, AY,
    'Двойной Ctrl: конвертировать набранную строку');

  AddSection(FMainPanel, AY, 'Звук и подсказки');
  FSoundSwitch := AddToggle(FMainPanel, AY, 'Звук при переключении');
  FHintMode := AddCombo(FMainPanel, AY, 'Подсказка у каретки',
    ['На время', 'Следует за кареткой', 'Не показывать']);
end;

procedure TfrmSettings.BuildAdvanced(var AY: Integer);
var
  X: Integer;
  First, Second: TButton;
begin
  AddSection(FAdvancedPanel, AY, 'Поведение');
  FSoundRU := AddToggle(FAdvancedPanel, AY, 'Звук при вводе в русской раскладке');
  FSelectionLayout := AddToggle(FAdvancedPanel, AY,
    'Менять раскладку после конвертации выделения');
  FPauseFullscreen := AddToggle(FAdvancedPanel, AY,
    'Не вмешиваться в полноэкранных приложениях');
  FHintFlash := AddToggle(FAdvancedPanel, AY, 'Вспышка подсказки при появлении');
  FHintAnimate := AddToggle(FAdvancedPanel, AY, 'Анимация размера подсказки');

  AddSection(FAdvancedPanel, AY, 'Слова и приложения');
  X := S(PageMargin);
  First := AddButton(FAdvancedPanel, 'Список обучения', X, AY, LearningListClick);
  Second := AddButton(FAdvancedPanel, 'Исключения', First.BoundsRect.Right + S(8),
    AY, ExclusionsClick);
  AddButton(FAdvancedPanel, 'Правила приложений', Second.BoundsRect.Right + S(8),
    AY, RulesClick);
  Inc(AY, S(38));
  AddButton(FAdvancedPanel, 'Сбросить обучение', X, AY, ResetLearningClick);
  Inc(AY, S(38));

  AddSection(FAdvancedPanel, AY, 'Диагностика');
  FDiagnostics := AddCombo(FAdvancedPanel, AY, 'Журнал',
    ['Выключен', 'Ошибки', 'Информация', 'Подробно']);
  First := AddButton(FAdvancedPanel, 'Открыть журнал', X, AY, OpenLogClick);
  AddButton(FAdvancedPanel, 'Очистить журнал', First.BoundsRect.Right + S(8),
    AY, ResetDiagnosticsClick);
  Inc(AY, S(38));
  AddButton(FAdvancedPanel, 'Открыть config.json', X, AY, OpenConfigClick);
  Inc(AY, S(44));
end;

constructor TfrmSettings.Create(AOwner: TComponent);
var
  Y, W: Integer;
  OkButton, CancelButton: TButton;
begin
  inherited CreateNew(AOwner);
  FDpi := GetDpiForSystem;
  if FDpi < 96 then
    FDpi := 96;
  Caption := 'Настройки Ghbdtn';
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu];
  Position := poScreenCenter;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  Color := clWindow;
  ClientWidth := S(500);
  ClientHeight := S(400);
  OnMouseWheel := WheelScroll;
  KeyPreview := True;

  FBar := TPanel.Create(Self);
  FBar.Parent := Self;
  FBar.Align := alBottom;
  FBar.Height := S(ButtonBarHeight);
  FBar.BevelOuter := bvNone;
  FBar.ParentBackground := False;
  FBar.Color := clBtnFace;

  FScroll := TScrollBox.Create(Self);
  FScroll.Parent := Self;
  FScroll.Align := alClient;
  FScroll.BorderStyle := bsNone;
  FScroll.HorzScrollBar.Visible := False;
  FScroll.VertScrollBar.Smooth := True;
  FScroll.VertScrollBar.Tracking := True;
  FScroll.Color := clWindow;

  W := ClientWidth - GetSystemMetrics(SM_CXVSCROLL);
  FMainPanel := TPanel.Create(Self);
  FMainPanel.Parent := FScroll;
  FMainPanel.BevelOuter := bvNone;
  FMainPanel.ParentBackground := False;
  FMainPanel.Color := clWindow;
  FMainPanel.SetBounds(0, 0, W, S(100));
  Y := 0;
  BuildMain(Y);

  FSpoiler := TLabel.Create(Self);
  FSpoiler.Parent := FMainPanel;
  FSpoiler.Cursor := crHandPoint;
  FSpoiler.Font.Style := [fsBold];
  FSpoiler.Font.Size := 10;
  FSpoiler.Font.Color := TColor($9E5A00);
  FSpoiler.Left := S(PageMargin);
  FSpoiler.Top := Y + S(SectionGap) + S(4);
  FSpoiler.OnClick := SpoilerClick;
  Y := FSpoiler.Top + S(SectionHeight) + S(4);
  FMainPanel.Height := Y;

  FAdvancedPanel := TPanel.Create(Self);
  FAdvancedPanel.Parent := FScroll;
  FAdvancedPanel.BevelOuter := bvNone;
  FAdvancedPanel.ParentBackground := False;
  FAdvancedPanel.Color := clWindow;
  FAdvancedPanel.SetBounds(0, FMainPanel.Height, W, S(100));
  Y := 0;
  BuildAdvanced(Y);
  FAdvancedPanel.Height := Y;
  FAdvancedPanel.Visible := False;

  CancelButton := TButton.Create(Self);
  CancelButton.Parent := FBar;
  CancelButton.Caption := 'Отмена';
  CancelButton.Cancel := True;
  CancelButton.ModalResult := mrCancel;
  CancelButton.SetBounds(ClientWidth - S(16) - S(96), S(13), S(96), S(30));
  CancelButton.Anchors := [akTop, akRight];

  FApplyButton := TButton.Create(Self);
  FApplyButton.Parent := FBar;
  FApplyButton.Caption := 'Применить';
  FApplyButton.OnClick := ApplyClick;
  FApplyButton.SetBounds(CancelButton.Left - S(8) - S(96), S(13), S(96), S(30));
  FApplyButton.Anchors := [akTop, akRight];

  OkButton := TButton.Create(Self);
  OkButton.Parent := FBar;
  OkButton.Caption := 'ОК';
  OkButton.Default := True;
  OkButton.OnClick := OkClick;
  OkButton.SetBounds(FApplyButton.Left - S(8) - S(96), S(13), S(96), S(30));
  OkButton.Anchors := [akTop, akRight];

  LoadValues;
  FAdvancedShown := False;
  SpoilerClick(nil);
  SpoilerClick(nil);
end;

procedure TfrmSettings.FitHeight;
var
  Content, Limit: Integer;
  Area: TRect;
begin
  Content := FMainPanel.Height;
  if FAdvancedShown then
    Inc(Content, FAdvancedPanel.Height);
  Area := Screen.WorkAreaRect;
  Limit := (Area.Bottom - Area.Top) * 9 div 10 - S(ButtonBarHeight) -
    (Height - ClientHeight);
  ClientHeight := Min(Content, Limit) + S(ButtonBarHeight);
  if FAdvancedShown then
    Top := Max(Area.Top, Min(Top, Area.Bottom - Height));
  FScroll.VertScrollBar.Range := Content;
  if Content <= FScroll.ClientHeight then
    FScroll.VertScrollBar.Position := 0;
end;

procedure TfrmSettings.SpoilerClick(Sender: TObject);
begin
  FAdvancedShown := not FAdvancedShown;
  FAdvancedPanel.Visible := FAdvancedShown;
  if FAdvancedShown then
    FSpoiler.Caption := #$25BE'  Дополнительно'
  else
    FSpoiler.Caption := #$25B8'  Дополнительно';
  FitHeight;
end;

procedure TfrmSettings.WheelScroll(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  FScroll.VertScrollBar.Position := FScroll.VertScrollBar.Position -
    WheelDelta div 2;
  Handled := True;
end;

procedure TfrmSettings.LoadValues;

  procedure SetOn(ASwitch: TSwitch; AValue: Boolean);
  begin
    ASwitch.Checked := AValue;
  end;

begin
  SetOn(FAutoSwitch, AppSettings.AutoSwitchEnabled);
  SetOn(FSoundRU, AppSettings.SoundOnRussianInput);
  SetOn(FSoundSwitch, AppSettings.SoundOnSwitch);
  SetOn(FDoubleShift, AppSettings.DoubleLeftShiftEnabled);
  SetOn(FSelectionLayout, AppSettings.SwitchLayoutAfterSelection);
  SetOn(FAutoStart, AppSettings.AutoStart);
  SetOn(FFixCaps, AppSettings.FixInitialCaps);
  SetOn(FFixCapsLock, AppSettings.FixCapsLock);
  SetOn(FPauseFullscreen, AppSettings.PauseInFullscreen);
  SetOn(FEnglishSecure, AppSettings.EnglishInSecureFields);
  SetOn(FDoubleCtrl, AppSettings.DoubleCtrlEnabled);
  SetOn(FEarlySwitch, AppSettings.EarlySwitchEnabled);
  FEarlyLetters.ItemIndex := AppSettings.EarlySwitchLetters - EarlyLettersMin;
  SetOn(FHintFlash, AppSettings.CaretHintFlash);
  SetOn(FHintAnimate, AppSettings.CaretHintAnimate);
  FMode.ItemIndex := Ord(AppSettings.HeuristicMode);
  FHintMode.ItemIndex := Ord(AppSettings.CaretHintMode);
  FDiagnostics.ItemIndex := Ord(AppSettings.DiagnosticsLevel);
end;

procedure TfrmSettings.ApplyValues;
begin
  AppSettings.AutoSwitchEnabled := FAutoSwitch.Checked;
  AppSettings.SoundOnRussianInput := FSoundRU.Checked;
  AppSettings.SoundOnSwitch := FSoundSwitch.Checked;
  AppSettings.DoubleLeftShiftEnabled := FDoubleShift.Checked;
  AppSettings.SwitchLayoutAfterSelection := FSelectionLayout.Checked;
  AppSettings.AutoStart := FAutoStart.Checked;
  AppSettings.FixInitialCaps := FFixCaps.Checked;
  AppSettings.FixCapsLock := FFixCapsLock.Checked;
  AppSettings.PauseInFullscreen := FPauseFullscreen.Checked;
  AppSettings.EnglishInSecureFields := FEnglishSecure.Checked;
  AppSettings.DoubleCtrlEnabled := FDoubleCtrl.Checked;
  AppSettings.EarlySwitchEnabled := FEarlySwitch.Checked;
  if FEarlyLetters.ItemIndex >= 0 then
    AppSettings.EarlySwitchLetters := FEarlyLetters.ItemIndex + EarlyLettersMin;
  AppSettings.CaretHintFlash := FHintFlash.Checked;
  AppSettings.CaretHintAnimate := FHintAnimate.Checked;
  if FMode.ItemIndex >= 0 then
    AppSettings.HeuristicMode := THeuristicMode(FMode.ItemIndex);
  if FHintMode.ItemIndex >= 0 then
    AppSettings.CaretHintMode := TCaretHintMode(FHintMode.ItemIndex);
  if FDiagnostics.ItemIndex >= 0 then
    AppSettings.DiagnosticsLevel := TDiagnosticsLevel(FDiagnostics.ItemIndex);
  AppSettings.SaveToFile;
  ApplyAutoStart(AppSettings.AutoStart);
  ConfigureDiagnostics(DiagnosticsLogPath, AppSettings.DiagnosticsLevel);
end;

procedure TfrmSettings.ApplyClick(Sender: TObject);
begin
  ApplyValues;
end;

procedure TfrmSettings.OkClick(Sender: TObject);
begin
  ApplyValues;
  ModalResult := mrOk;
end;

procedure TfrmSettings.ExclusionsClick(Sender: TObject);
begin
  EditExclusions;
end;

procedure TfrmSettings.RulesClick(Sender: TObject);
begin
  EditApplicationRules;
end;

procedure TfrmSettings.LearningListClick(Sender: TObject);
var
  Dialog: TLearningListDialog;
begin
  Dialog := TLearningListDialog.Create;
  try
    Dialog.Show;
  finally
    Dialog.Free;
  end;
end;

procedure TfrmSettings.ResetLearningClick(Sender: TObject);
begin
  if MessageDlg('Забыть всё, чему программа научилась на ваших отменах?',
     mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  AppSettings.ResetLearning;
  AppSettings.SaveToFile;
end;

procedure TfrmSettings.ResetDiagnosticsClick(Sender: TObject);
begin
  ResetDiagnostics;
end;

procedure TfrmSettings.OpenLogClick(Sender: TObject);
begin
  if TFile.Exists(DiagnosticsLogPath) then
    ShellExecute(0, 'open', PChar(DiagnosticsLogPath), nil, nil, SW_SHOWNORMAL)
  else
    MessageDlg('Журнал пуст.', mtInformation, [mbOK], 0);
end;

procedure TfrmSettings.OpenConfigClick(Sender: TObject);
begin
  ShellExecute(0, 'open', PChar(AppSettings.ConfigFilePath), nil, nil,
    SW_SHOWNORMAL);
end;

function EditAppSettings: Boolean;
var
  Dialog: TfrmSettings;
begin
  Dialog := TfrmSettings.Create(Application);
  try
    Result := Dialog.ShowModal = mrOk;
  finally
    Dialog.Free;
  end;
end;

end.
