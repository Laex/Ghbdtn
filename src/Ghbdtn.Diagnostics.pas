unit Ghbdtn.Diagnostics;

interface

type
  TDiagnosticsLevel = (dlOff, dlError, dlInfo, dlVerbose);
  TDiagnosticEvent = (
    deHookInstallFailed,
    deHookUninstallFailed,
    deWorkerFailure,
    deClipboardSnapshotFailed,
    deClipboardRestoreFailed,
    deClipboardReadFailed,
    deClipboardWriteFailed,
    deSettingsLoadFailed,
    deSettingsSaveFailed,
    deSettingsRecovered,
    deTimerFailure,
    deTrayUpdateFailed,
    deSingleInstanceFailed,
    deHeuristicDecision,
    deHookFailure,
    deStaleWorkDropped,
    deUpdateCheckFailed,
    deUpdateCurrent
  );

procedure ConfigureDiagnostics(const AFilePath: string;
  ALevel: TDiagnosticsLevel);
procedure LogDiagnostic(ALevel: TDiagnosticsLevel;
  AEvent: TDiagnosticEvent; AErrorCode: Integer = 0;
  const ADetail: string = '');
procedure ResetDiagnostics;
function EffectiveDiagnosticsLevel: TDiagnosticsLevel;
function DiagnosticEventName(AEvent: TDiagnosticEvent): string;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.SyncObjs;

const
  // A verbose session writes one line per finished word.
  MaxLogBytes = 512 * 1024;
  MaxRotatedFiles = 2;

var
  DiagnosticsLock: TCriticalSection;
  DiagnosticsPath: string;
  RequestedLevel: TDiagnosticsLevel;

function EffectiveDiagnosticsLevel: TDiagnosticsLevel;
begin
  DiagnosticsLock.Acquire;
  try
{$IFDEF RELEASE}
    if RequestedLevel > dlError then
      Result := dlError
    else
{$ENDIF}
      Result := RequestedLevel;
  finally
    DiagnosticsLock.Release;
  end;
end;

function DiagnosticEventName(AEvent: TDiagnosticEvent): string;
begin
  case AEvent of
    deHookInstallFailed: Result := 'hook_install_failed';
    deHookUninstallFailed: Result := 'hook_uninstall_failed';
    deWorkerFailure: Result := 'worker_failure';
    deClipboardSnapshotFailed: Result := 'clipboard_snapshot_failed';
    deClipboardRestoreFailed: Result := 'clipboard_restore_failed';
    deClipboardReadFailed: Result := 'clipboard_read_failed';
    deClipboardWriteFailed: Result := 'clipboard_write_failed';
    deSettingsLoadFailed: Result := 'settings_load_failed';
    deSettingsSaveFailed: Result := 'settings_save_failed';
    deSettingsRecovered: Result := 'settings_recovered';
    deTimerFailure: Result := 'timer_failure';
    deTrayUpdateFailed: Result := 'tray_update_failed';
    deSingleInstanceFailed: Result := 'single_instance_failed';
    deHeuristicDecision: Result := 'heuristic_decision';
    deHookFailure: Result := 'hook_failure';
    deStaleWorkDropped: Result := 'stale_work_dropped';
    deUpdateCheckFailed: Result := 'update_check_failed';
    deUpdateCurrent: Result := 'update_current';
  else
    Result := 'unknown';
  end;
end;

procedure ConfigureDiagnostics(const AFilePath: string;
  ALevel: TDiagnosticsLevel);
begin
  DiagnosticsLock.Acquire;
  try
    DiagnosticsPath := AFilePath;
    RequestedLevel := ALevel;
  finally
    DiagnosticsLock.Release;
  end;
end;

procedure RotateIfNeeded;
var
  I: Integer;
  SourcePath: string;
  DestinationPath: string;
begin
  if not FileExists(DiagnosticsPath) or
     (TFile.GetSize(DiagnosticsPath) < MaxLogBytes) then
    Exit;
  for I := MaxRotatedFiles downto 1 do
  begin
    if I = 1 then
      SourcePath := DiagnosticsPath
    else
      SourcePath := DiagnosticsPath + '.' + IntToStr(I - 1);
    DestinationPath := DiagnosticsPath + '.' + IntToStr(I);
    if FileExists(DestinationPath) then
      TFile.Delete(DestinationPath);
    if FileExists(SourcePath) then
      TFile.Move(SourcePath, DestinationPath);
  end;
end;

procedure LogDiagnostic(ALevel: TDiagnosticsLevel;
  AEvent: TDiagnosticEvent; AErrorCode: Integer; const ADetail: string);
var
  Line: string;
begin
  DiagnosticsLock.Acquire;
  try
    try
      if (DiagnosticsPath <> '') and (ALevel <> dlOff) and
         (ALevel <= EffectiveDiagnosticsLevel) then
      begin
        RotateIfNeeded;
        Line := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', Now) + ' level=' +
          IntToStr(Ord(ALevel)) + ' event=' + DiagnosticEventName(AEvent);
        if AErrorCode <> 0 then
          Line := Line + ' code=' + IntToStr(AErrorCode);
        if ADetail <> '' then
          Line := Line + ' ' + ADetail;
        TFile.AppendAllText(DiagnosticsPath, Line + sLineBreak, TEncoding.UTF8);
      end;
    except
      { Diagnostics must never affect input processing or application shutdown. }
    end;
  finally
    DiagnosticsLock.Release;
  end;
end;

procedure ResetDiagnostics;
var
  I: Integer;
  Path: string;
begin
  DiagnosticsLock.Acquire;
  try
    for I := MaxRotatedFiles downto 0 do
    begin
      if I = 0 then
        Path := DiagnosticsPath
      else
        Path := DiagnosticsPath + '.' + IntToStr(I);
      if (Path <> '') and FileExists(Path) then
        TFile.Delete(Path);
    end;
  finally
    DiagnosticsLock.Release;
  end;
end;

initialization
  DiagnosticsLock := TCriticalSection.Create;
  RequestedLevel := dlOff;

finalization
  DiagnosticsLock.Free;

end.
