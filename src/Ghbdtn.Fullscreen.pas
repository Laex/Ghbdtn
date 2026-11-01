unit Ghbdtn.Fullscreen;

interface

{ Values of QUERY_USER_NOTIFICATION_STATE returned by
  SHQueryUserNotificationState. }
const
  QUNS_NOT_PRESENT = 1;
  QUNS_BUSY = 2;
  QUNS_RUNNING_D3D_FULL_SCREEN = 3;
  QUNS_PRESENTATION_MODE = 4;
  QUNS_ACCEPTS_NOTIFICATIONS = 5;

{ A full-screen application (a game, a video, a slide show) owns the
  keyboard: its keys must not be rewritten or swallowed. }
function IsFullscreenNotificationState(AState: Integer): Boolean;
function IsForegroundFullscreen: Boolean;

implementation

uses
  Winapi.Windows, Winapi.MultiMon;

function SHQueryUserNotificationState(out AState: Integer): HRESULT; stdcall;
  external 'shell32.dll' name 'SHQueryUserNotificationState';

function IsFullscreenNotificationState(AState: Integer): Boolean;
begin
  Result := AState in [QUNS_BUSY, QUNS_RUNNING_D3D_FULL_SCREEN,
    QUNS_PRESENTATION_MODE];
end;

{ The shell state is session-wide: a full-screen application on one monitor
  reports it while the user works in a window on another monitor. The
  foreground window itself must also cover its whole monitor. }
function ForegroundCoversMonitor: Boolean;
var
  Wnd: HWND;
  Mon: HMONITOR;
  Info: TMonitorInfo;
  R: TRect;
begin
  Wnd := GetForegroundWindow;
  if Wnd = 0 then
    Exit(False);
  Mon := MonitorFromWindow(Wnd, MONITOR_DEFAULTTONEAREST);
  Info.cbSize := SizeOf(Info);
  if (Mon = 0) or not GetMonitorInfo(Mon, @Info) or not GetWindowRect(Wnd, R) then
    Exit(False);
  Result := (R.Left <= Info.rcMonitor.Left) and (R.Top <= Info.rcMonitor.Top) and
    (R.Right >= Info.rcMonitor.Right) and (R.Bottom >= Info.rcMonitor.Bottom);
end;

function IsForegroundFullscreen: Boolean;
var
  State: Integer;
begin
  State := QUNS_ACCEPTS_NOTIFICATIONS;
  Result := Succeeded(SHQueryUserNotificationState(State)) and
    IsFullscreenNotificationState(State) and ForegroundCoversMonitor;
end;

end.
