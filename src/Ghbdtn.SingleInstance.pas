unit Ghbdtn.SingleInstance;

interface

uses
  Winapi.Windows;

type
  TSingleInstanceGuard = class
  private
    FHandle: THandle;
    FIsPrimary: Boolean;
  public
    constructor Create(const AMutexName: string);
    destructor Destroy; override;
    property IsPrimary: Boolean read FIsPrimary;
  end;

implementation

uses
  Ghbdtn.Diagnostics;

constructor TSingleInstanceGuard.Create(const AMutexName: string);
var
  ErrorCode: DWORD;
begin
  inherited Create;
  FHandle := CreateMutex(nil, False, PChar(AMutexName));
  ErrorCode := GetLastError;
  FIsPrimary := (FHandle <> 0) and (ErrorCode <> ERROR_ALREADY_EXISTS);
  if FHandle = 0 then
    LogDiagnostic(dlError, deSingleInstanceFailed, ErrorCode);
end;

destructor TSingleInstanceGuard.Destroy;
begin
  if FHandle <> 0 then
    CloseHandle(FHandle);
  inherited Destroy;
end;

end.
