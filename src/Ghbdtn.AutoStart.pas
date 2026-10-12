unit Ghbdtn.AutoStart;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Win.Registry;

procedure ApplyAutoStart(AEnabled: Boolean);

implementation

const
  RunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  RunValueName = 'Ghbdtn';

procedure ApplyAutoStart(AEnabled: Boolean);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if not Reg.OpenKey(RunKey, True) then
      Exit;

    if AEnabled then
      Reg.WriteString(RunValueName, '"' + ParamStr(0) + '"')
    else if Reg.ValueExists(RunValueName) then
      Reg.DeleteValue(RunValueName);
  finally
    Reg.Free;
  end;
end;

end.
