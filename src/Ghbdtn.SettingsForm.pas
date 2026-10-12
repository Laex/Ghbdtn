unit Ghbdtn.SettingsForm;

interface

function EditAppSettings: Boolean;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Ghbdtn.Analyzer,
  Ghbdtn.Diagnostics,
  Ghbdtn.Learning,
  Ghbdtn.Settings,
  Ghbdtn.AutoStart,
  Ghbdtn.Hook;

type
  TfrmSettings = class(TForm)
  private
    FAutoSwitch: TCheckBox;
    FSoundRU: TCheckBox;
    FSoundSwitch: TCheckBox;
    FDoubleShift: TCheckBox;
    FSelectionLayout: TCheckBox;
    FAutoStart: TCheckBox;
    FHintFlash: TCheckBox;
    FHintAnimate: TCheckBox;
    FMode: TRadioGroup;
    FHintMode: TRadioGroup;
    FDiagnostics: TRadioGroup;
    procedure LoadValues;
    procedure ApplyValues;
    procedure ResetLearningClick(Sender: TObject);
    procedure LearningListClick(Sender: TObject);
    procedure ExclusionsClick(Sender: TObject);
    procedure RulesClick(Sender: TObject);
    procedure ResetDiagnosticsClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

function MakeCheck(AOwner: TWinControl; const ACaption: string;
  ALeft, ATop, AWidth: Integer): TCheckBox;
begin
  Result := TCheckBox.Create(AOwner);
  Result.Parent := AOwner;
  Result.Caption := ACaption;
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Width := AWidth;
end;

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

procedure FitCaption(AForm: TForm; AButton: TButton; AMinWidth: Integer);
begin
  AButton.Width := AForm.Canvas.TextWidth(AButton.Caption) + 36;
  if AButton.Width < AMinWidth then
    AButton.Width := AMinWidth;
end;

constructor TfrmSettings.Create(AOwner: TComponent);
var
  OkButton, CancelButton, ResetLearning, LearningList, ResetDiagnostics,
    ExclusionsButton, RulesButton: TButton;
  Need, ButtonTop, RowWidth: Integer;
begin
  inherited CreateNew(AOwner);
  Caption := 'Настройки';
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  ClientWidth := 460;
  ClientHeight := 592;
  Font.Name := 'Segoe UI';
  Font.Height := -12;

  FAutoSwitch := MakeCheck(Self, 'Автопереключение', 16, 16, 420);
  FSoundRU := MakeCheck(Self, 'Звук при вводе в RU', 16, 40, 420);
  FSoundSwitch := MakeCheck(Self, 'Звук при переключении', 16, 64, 420);
  FDoubleShift := MakeCheck(Self, 'Двойной Left Shift', 16, 88, 420);
  FSelectionLayout := MakeCheck(Self,
    'Менять раскладку после конвертации выделения', 16, 112, 420);
  FAutoStart := MakeCheck(Self, 'Автозапуск', 16, 136, 420);

  FMode := TRadioGroup.Create(Self);
  FMode.Parent := Self;
  FMode.Caption := 'Эвристика';
  FMode.Left := 16;
  FMode.Top := 168;
  FMode.Width := 428;
  FMode.Height := 78;
  FMode.Items.Add('Осторожный');
  FMode.Items.Add('Сбалансированный');
  FMode.Items.Add('Агрессивный');

  FHintMode := TRadioGroup.Create(Self);
  FHintMode.Parent := Self;
  FHintMode.Caption := 'Подсказка у каретки';
  FHintMode.Left := 16;
  FHintMode.Top := 254;
  FHintMode.Width := 428;
  FHintMode.Height := 78;
  FHintMode.Items.Add('На время');
  FHintMode.Items.Add('Следовать за кареткой');
  FHintMode.Items.Add('Не показывать');

  FHintFlash := MakeCheck(Self, 'Вспышка при появлении', 28, 338, 190);
  FHintAnimate := MakeCheck(Self, 'Анимация размера', 230, 338, 190);

  FDiagnostics := TRadioGroup.Create(Self);
  FDiagnostics.Parent := Self;
  FDiagnostics.Caption := 'Диагностика';
  FDiagnostics.Left := 16;
  FDiagnostics.Top := 366;
  FDiagnostics.Width := 428;
  FDiagnostics.Height := 96;
  FDiagnostics.Columns := 2;
  FDiagnostics.Items.Add('Выкл.');
  FDiagnostics.Items.Add('Ошибки');
  FDiagnostics.Items.Add('Информация');
  FDiagnostics.Items.Add('Подробно');

  LearningList := TButton.Create(Self);
  LearningList.Parent := Self;
  LearningList.Caption := 'Список обучения';
  LearningList.Height := 28;
  LearningList.OnClick := LearningListClick;
  FitCaption(Self, LearningList, 140);

  ExclusionsButton := TButton.Create(Self);
  ExclusionsButton.Parent := Self;
  ExclusionsButton.Caption := 'Исключения';
  ExclusionsButton.Height := 28;
  ExclusionsButton.OnClick := ExclusionsClick;
  FitCaption(Self, ExclusionsButton, 110);

  RulesButton := TButton.Create(Self);
  RulesButton.Parent := Self;
  RulesButton.Caption := 'Правила приложений';
  RulesButton.Height := 28;
  RulesButton.OnClick := RulesClick;
  FitCaption(Self, RulesButton, 160);

  ResetLearning := TButton.Create(Self);
  ResetLearning.Parent := Self;
  ResetLearning.Caption := 'Сбросить обучение';
  ResetLearning.Height := 28;
  ResetLearning.OnClick := ResetLearningClick;
  FitCaption(Self, ResetLearning, 120);

  ResetDiagnostics := TButton.Create(Self);
  ResetDiagnostics.Parent := Self;
  ResetDiagnostics.Caption := 'Очистить диагностику';
  ResetDiagnostics.Height := 28;
  ResetDiagnostics.OnClick := ResetDiagnosticsClick;
  FitCaption(Self, ResetDiagnostics, 160);

  OkButton := TButton.Create(Self);
  OkButton.Parent := Self;
  OkButton.Caption := 'ОК';
  OkButton.Height := 28;
  OkButton.Default := True;
  OkButton.ModalResult := mrOk;
  FitCaption(Self, OkButton, 84);

  CancelButton := TButton.Create(Self);
  CancelButton.Parent := Self;
  CancelButton.Caption := 'Отмена';
  CancelButton.Height := 28;
  CancelButton.Cancel := True;
  CancelButton.ModalResult := mrCancel;
  FitCaption(Self, CancelButton, 84);

  Need := 16 + ResetLearning.Width + 8 + ResetDiagnostics.Width + 24 +
    OkButton.Width + 8 + CancelButton.Width + 16;
  RowWidth := 16 + LearningList.Width + 8 + ExclusionsButton.Width + 8 +
    RulesButton.Width + 16;
  if Need < RowWidth then
    Need := RowWidth;
  if ClientWidth < Need then
    ClientWidth := Need;
  FMode.Width := ClientWidth - 32;
  FHintMode.Width := ClientWidth - 32;
  FDiagnostics.Width := ClientWidth - 32;
  FAutoSwitch.Width := ClientWidth - 40;
  FSoundRU.Width := ClientWidth - 40;
  FSoundSwitch.Width := ClientWidth - 40;
  FDoubleShift.Width := ClientWidth - 40;
  FSelectionLayout.Width := ClientWidth - 40;
  FAutoStart.Width := ClientWidth - 40;

  ButtonTop := ClientHeight - 16 - ResetLearning.Height;
  LearningList.SetBounds(16, ButtonTop - 36, LearningList.Width, LearningList.Height);
  ExclusionsButton.SetBounds(LearningList.BoundsRect.Right + 8, ButtonTop - 36,
    ExclusionsButton.Width, ExclusionsButton.Height);
  RulesButton.SetBounds(ExclusionsButton.BoundsRect.Right + 8, ButtonTop - 36,
    RulesButton.Width, RulesButton.Height);
  ResetLearning.SetBounds(16, ButtonTop, ResetLearning.Width, ResetLearning.Height);
  ResetDiagnostics.SetBounds(ResetLearning.BoundsRect.Right + 8, ButtonTop,
    ResetDiagnostics.Width, ResetDiagnostics.Height);
  CancelButton.SetBounds(ClientWidth - 16 - CancelButton.Width, ButtonTop,
    CancelButton.Width, CancelButton.Height);
  OkButton.SetBounds(CancelButton.Left - 8 - OkButton.Width, ButtonTop,
    OkButton.Width, OkButton.Height);

  LoadValues;
end;

procedure TfrmSettings.LoadValues;
begin
  FAutoSwitch.Checked := AppSettings.AutoSwitchEnabled;
  FSoundRU.Checked := AppSettings.SoundOnRussianInput;
  FSoundSwitch.Checked := AppSettings.SoundOnSwitch;
  FDoubleShift.Checked := AppSettings.DoubleLeftShiftEnabled;
  FSelectionLayout.Checked := AppSettings.SwitchLayoutAfterSelection;
  FAutoStart.Checked := AppSettings.AutoStart;
  FHintFlash.Checked := AppSettings.CaretHintFlash;
  FHintAnimate.Checked := AppSettings.CaretHintAnimate;
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
  ConfigureDiagnostics(TPath.Combine(ExtractFilePath(ParamStr(0)),
    'diagnostics.log'), AppSettings.DiagnosticsLevel);
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
  AppSettings.ResetLearning;
  AppSettings.SaveToFile;
end;

procedure TfrmSettings.ResetDiagnosticsClick(Sender: TObject);
begin
  ResetDiagnostics;
end;

function EditAppSettings: Boolean;
var
  Dialog: TfrmSettings;
begin
  Dialog := TfrmSettings.Create(Application);
  try
    Result := Dialog.ShowModal = mrOk;
    if Result then
      Dialog.ApplyValues;
  finally
    Dialog.Free;
  end;
end;

end.
