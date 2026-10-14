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
  Winapi.Windows;

function SHQueryUserNotificationState(out AState: Integer): HRESULT; stdcall;
  external 'shell32.dll' name 'SHQueryUserNotificationState';

function IsFullscreenNotificationState(AState: Integer): Boolean;
begin
  Result := AState in [QUNS_BUSY, QUNS_RUNNING_D3D_FULL_SCREEN,
    QUNS_PRESENTATION_MODE];
end;

function IsForegroundFullscreen: Boolean;
var
  State: Integer;
begin
  State := QUNS_ACCEPTS_NOTIFICATIONS;
  Result := Succeeded(SHQueryUserNotificationState(State)) and
    IsFullscreenNotificationState(State);
end;

end.
