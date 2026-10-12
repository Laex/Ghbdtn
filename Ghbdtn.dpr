program Ghbdtn;

uses
  Winapi.Windows,
  Vcl.Forms,
  System.SysUtils,
  Ghbdtn.App in 'src\Ghbdtn.App.pas',
  Ghbdtn.Layout in 'src\Ghbdtn.Layout.pas',
  Ghbdtn.TrayIcon in 'src\Ghbdtn.TrayIcon.pas',
  Ghbdtn.Sound in 'src\Ghbdtn.Sound.pas',
  Ghbdtn.Settings in 'src\Ghbdtn.Settings.pas',
  Ghbdtn.AutoStart in 'src\Ghbdtn.AutoStart.pas',
  Ghbdtn.Buffer in 'src\Ghbdtn.Buffer.pas',
  Ghbdtn.KeyState in 'src\Ghbdtn.KeyState.pas',
  Ghbdtn.Learning in 'src\Ghbdtn.Learning.pas',
  Ghbdtn.Phrase in 'src\Ghbdtn.Phrase.pas',
  Ghbdtn.Heuristics in 'src\Ghbdtn.Heuristics.pas',
  Ghbdtn.Analyzer in 'src\Ghbdtn.Analyzer.pas',
  Ghbdtn.Fixer in 'src\Ghbdtn.Fixer.pas',
  Ghbdtn.Diagnostics in 'src\Ghbdtn.Diagnostics.pas',
  Ghbdtn.SingleInstance in 'src\Ghbdtn.SingleInstance.pas',
  Ghbdtn.InputQueue in 'src\Ghbdtn.InputQueue.pas',
  Ghbdtn.InputWorker in 'src\Ghbdtn.InputWorker.pas',
  Ghbdtn.Password in 'src\Ghbdtn.Password.pas',
  Ghbdtn.CaretHint in 'src\Ghbdtn.CaretHint.pas',
  Ghbdtn.SettingsForm in 'src\Ghbdtn.SettingsForm.pas',
  Ghbdtn.Hook in 'src\Ghbdtn.Hook.pas',
  Ghbdtn.Update in 'src\Ghbdtn.Update.pas';

{$R *.res}

var
  InstanceGuard: TSingleInstanceGuard;
begin
{$IFDEF GHBDTN_UPDATE}
  // An update restart waits until the previous process releases the mutex,
  // then removes the renamed exe that process left behind.
  WaitForPreviousInstance;
  CleanupOldFiles(ExtractFilePath(ParamStr(0)));
{$ENDIF}
  InstanceGuard := TSingleInstanceGuard.Create(
    'Local\Ghbdtn.SingleInstance.v2');
  if not InstanceGuard.IsPrimary then
  begin
    InstanceGuard.Free;
    Exit;
  end;
  try
    Application.Initialize;
    InitializeSound;
    Application.MainFormOnTaskbar := False;
    Application.ShowMainForm := False;
    Application.Title := 'Ghbdtn';
    Application.CreateForm(TfrmApp, frmApp);
    Application.Run;
  finally
    InstanceGuard.Free;
  end;
end.
