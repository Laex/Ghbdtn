unit Ghbdtn.LayoutIndicator;

interface

{ Hides or restores the layout indicator that Windows shows in the notification
  area. The indicator is switched through the Enabled value of the input
  indicator key; the value found before hiding is kept under the program's own
  key so that restoring puts back exactly what was there, also after the
  program was killed while the indicator was hidden. Both calls are idempotent. }
procedure ApplySystemIndicatorHidden(AHide: Boolean);

{ The same operation with explicit registry paths under HKEY_CURRENT_USER. }
procedure ApplyIndicatorState(AHide: Boolean; const AIndicatorKey,
  ABackupKey: string);

implementation

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Win.Registry;

const
  IndicatorKey = 'Software\Microsoft\Input\TIPC';
  IndicatorValue = 'Enabled';
  BackupKey = 'Software\Ghbdtn';
  BackupValue = 'InputIndicatorBackup';
  // Stored in place of a number when the indicator value did not exist.
  BackupAbsent = 'absent';

function ReadBackup(AReg: TRegistry; const AKey: string;
  out ABackup: string): Boolean;
begin
  Result := False;
  ABackup := '';
  if AReg.OpenKey(AKey, False) then
  try
    if AReg.ValueExists(BackupValue) then
    begin
      ABackup := AReg.ReadString(BackupValue);
      Result := ABackup <> '';
    end;
  finally
    AReg.CloseKey;
  end;
end;

function CurrentIndicatorState(AReg: TRegistry; const AKey: string): string;
begin
  Result := BackupAbsent;
  if AReg.OpenKey(AKey, False) then
  try
    if AReg.ValueExists(IndicatorValue) then
      Result := IntToStr(AReg.ReadInteger(IndicatorValue));
  finally
    AReg.CloseKey;
  end;
end;

procedure WriteIndicator(AReg: TRegistry; const AKey, AState: string);
begin
  if AState = BackupAbsent then
  begin
    if AReg.OpenKey(AKey, False) then
    try
      if AReg.ValueExists(IndicatorValue) then
        AReg.DeleteValue(IndicatorValue);
    finally
      AReg.CloseKey;
    end;
  end
  else if AReg.OpenKey(AKey, True) then
  try
    AReg.WriteInteger(IndicatorValue, StrToIntDef(AState, 1));
  finally
    AReg.CloseKey;
  end;
end;

procedure ApplyIndicatorState(AHide: Boolean; const AIndicatorKey,
  ABackupKey: string);
var
  Reg: TRegistry;
  Backup: string;
begin
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    try
      if AHide then
      begin
        if not ReadBackup(Reg, ABackupKey, Backup) then
        begin
          Backup := CurrentIndicatorState(Reg, AIndicatorKey);
          if Reg.OpenKey(ABackupKey, True) then
          try
            Reg.WriteString(BackupValue, Backup);
          finally
            Reg.CloseKey;
          end;
        end;
        WriteIndicator(Reg, AIndicatorKey, '0');
      end
      else if ReadBackup(Reg, ABackupKey, Backup) then
      begin
        WriteIndicator(Reg, AIndicatorKey, Backup);
        if Reg.OpenKey(ABackupKey, False) then
        try
          Reg.DeleteValue(BackupValue);
        finally
          Reg.CloseKey;
        end;
      end;
    except
      // An unexpected value type or a locked key must not stop the program.
      on ERegistryException do;
    end;
  finally
    Reg.Free;
  end;
end;

procedure ApplySystemIndicatorHidden(AHide: Boolean);
var
  Reg: TRegistry;
  Backup: string;
  Changed: Boolean;
  Reply: DWORD_PTR;
begin
  Changed := True;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    try
      // Hiding is a change unless the indicator is already off and recorded;
      // restoring is one only while a backup exists.
      if AHide then
        Changed := not ReadBackup(Reg, BackupKey, Backup) or
          (CurrentIndicatorState(Reg, IndicatorKey) <> '0')
      else
        Changed := ReadBackup(Reg, BackupKey, Backup);
    except
      on ERegistryException do;
    end;
  finally
    Reg.Free;
  end;
  ApplyIndicatorState(AHide, IndicatorKey, BackupKey);
  if Changed then
    // The shell rereads its notification area settings on this notification.
    SendMessageTimeout(HWND_BROADCAST, WM_SETTINGCHANGE, 0,
      LPARAM(PChar('TraySettings')), SMTO_ABORTIFHUNG, 1000, @Reply);
end;

end.
