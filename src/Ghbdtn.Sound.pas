unit Ghbdtn.Sound;

interface

uses
  Ghbdtn.Layout;

procedure InitializeSound;
procedure PlaySwitchBeep(ATarget: TLangKind);
procedure PlayKeyClickRU;
procedure ShutdownSound;

implementation

uses
  Winapi.Windows,
  Winapi.MMSystem,
  System.SysUtils,
  System.Classes,
  System.Math,
  System.SyncObjs,
  Ghbdtn.Diagnostics;

type
  TSoundWorker = class(TThread)
  private
    FLock: TCriticalSection;
    FSignal: TEvent;
    FSwitchLang: TLangKind;
    FClickPending: Boolean;
    FShuttingDown: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure QueueSwitch(ATarget: TLangKind);
    procedure QueueClick;
    procedure Shutdown;
  end;

var
  SoundWorker: TSoundWorker;

constructor TSoundWorker.Create;
begin
  // Must stay suspended here: Start inside Create races AfterConstruction.
  inherited Create(True);
  FreeOnTerminate := False;
  FLock := TCriticalSection.Create;
  FSignal := TEvent.Create(nil, False, False, '');
end;

destructor TSoundWorker.Destroy;
begin
  FSignal.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TSoundWorker.QueueSwitch(ATarget: TLangKind);
begin
  if ATarget = lkUnknown then
    Exit;
  FLock.Acquire;
  try
    if not FShuttingDown then
    begin
      FSwitchLang := ATarget;
      FSignal.SetEvent;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TSoundWorker.QueueClick;
begin
  FLock.Acquire;
  try
    if not FShuttingDown then
    begin
      FClickPending := True;
      FSignal.SetEvent;
    end;
  finally
    FLock.Release;
  end;
end;

procedure AppendSegment(var ASamples: TBytes; AFrequency, ADurationMs: Integer);
const
  SampleRate = 44100;
var
  SampleCount, I, Fade, Base: Integer;
  Amplitude: Double;
begin
  if ADurationMs <= 0 then
    Exit;
  SampleCount := (SampleRate * ADurationMs) div 1000;
  if SampleCount < 1 then
    Exit;
  Base := Length(ASamples);
  SetLength(ASamples, Base + SampleCount * 2);
  Fade := SampleRate div 200;
  if Fade > SampleCount div 4 then
    Fade := SampleCount div 4;
  for I := 0 to SampleCount - 1 do
  begin
    if AFrequency <= 0 then
      Amplitude := 0
    else
    begin
      Amplitude := 9000;
      if I < Fade then
        Amplitude := Amplitude * I / Fade
      else if I > SampleCount - Fade then
        Amplitude := Amplitude * (SampleCount - I) / Fade;
    end;
    PSmallInt(@ASamples[Base + I * 2])^ :=
      Round(Sin(2 * Pi * AFrequency * I / SampleRate) * Amplitude);
  end;
end;

const
  SampleRate = 44100;
  IdleSilenceMs = 100;
  ColdLeadInMs = 80;
  DeviceIdleCloseMs = 20000;

var
  // Owned by the sound thread. The output stream stays open (playing silence)
  // between tones: reopening it for every 12 ms click lets the audio endpoint
  // power down in between, and the next click is then swallowed while it wakes.
  GDevice: HWAVEOUT;
  GIdleHeader: TWaveHdr;
  GIdleBuffer: TBytes;
  GIdleActive: Boolean;
  GLastPlayTick: UInt64;

procedure StopIdleLoop;
begin
  if not GIdleActive then
    Exit;
  waveOutReset(GDevice);
  waveOutUnprepareHeader(GDevice, @GIdleHeader, SizeOf(GIdleHeader));
  GIdleActive := False;
end;

procedure CloseDevice;
begin
  if GDevice = 0 then
    Exit;
  StopIdleLoop;
  waveOutClose(GDevice);
  GDevice := 0;
end;

procedure StartIdleLoop;
begin
  if (GDevice = 0) or GIdleActive then
    Exit;
  if Length(GIdleBuffer) = 0 then
    SetLength(GIdleBuffer, (SampleRate * IdleSilenceMs div 1000) * 2);
  ZeroMemory(@GIdleHeader, SizeOf(GIdleHeader));
  GIdleHeader.lpData := PAnsiChar(@GIdleBuffer[0]);
  GIdleHeader.dwBufferLength := Length(GIdleBuffer);
  GIdleHeader.dwFlags := WHDR_BEGINLOOP or WHDR_ENDLOOP;
  GIdleHeader.dwLoops := High(Cardinal);
  if waveOutPrepareHeader(GDevice, @GIdleHeader, SizeOf(GIdleHeader)) <> MMSYSERR_NOERROR then
  begin
    CloseDevice;
    Exit;
  end;
  // PrepareHeader clears the flags it does not own, so set the loop bits again.
  GIdleHeader.dwFlags := GIdleHeader.dwFlags or WHDR_BEGINLOOP or WHDR_ENDLOOP;
  GIdleActive := True;
  if waveOutWrite(GDevice, @GIdleHeader, SizeOf(GIdleHeader)) <> MMSYSERR_NOERROR then
    CloseDevice;
end;

function OpenDevice: Boolean;
var
  Format: TWaveFormatEx;
begin
  if GDevice <> 0 then
    Exit(True);
  ZeroMemory(@Format, SizeOf(Format));
  Format.wFormatTag := WAVE_FORMAT_PCM;
  Format.nChannels := 1;
  Format.nSamplesPerSec := SampleRate;
  Format.wBitsPerSample := 16;
  Format.nBlockAlign := 2;
  Format.nAvgBytesPerSec := SampleRate * 2;
  // WAVE_MAPPER opens the current default endpoint. The device is closed after
  // a quiet spell, so a switch from speakers to headphones is picked up then.
  Result := waveOutOpen(@GDevice, WAVE_MAPPER, @Format, 0, 0, CALLBACK_NULL) =
    MMSYSERR_NOERROR;
  if not Result then
    GDevice := 0;
end;

procedure PlaySamples(const ASamples: TBytes; ADurationMs: Integer);
var
  Header: TWaveHdr;
  Deadline: UInt64;
  Buffer: TBytes;
  Cold: Boolean;
  LeadIn: Integer;
begin
  if Length(ASamples) < 2 then
    Exit;
  Cold := GDevice = 0;
  if not OpenDevice then
    Exit;
  StopIdleLoop;
  Buffer := ASamples;
  if Cold then
  begin
    // A freshly opened stream clips its first milliseconds while the endpoint
    // starts, so the tone is preceded by silence.
    LeadIn := (SampleRate * ColdLeadInMs div 1000) * 2;
    SetLength(Buffer, LeadIn + Length(ASamples));
    FillChar(Buffer[0], LeadIn, 0);
    Move(ASamples[0], Buffer[LeadIn], Length(ASamples));
    Inc(ADurationMs, ColdLeadInMs);
  end;
  ZeroMemory(@Header, SizeOf(Header));
  Header.lpData := PAnsiChar(@Buffer[0]);
  Header.dwBufferLength := Length(Buffer);
  if waveOutPrepareHeader(GDevice, @Header, SizeOf(Header)) <> MMSYSERR_NOERROR then
  begin
    CloseDevice;
    Exit;
  end;
  try
    if waveOutWrite(GDevice, @Header, SizeOf(Header)) <> MMSYSERR_NOERROR then
    begin
      CloseDevice;
      Exit;
    end;
    Deadline := GetTickCount64 + Cardinal(ADurationMs) + 300;
    while ((Header.dwFlags and WHDR_DONE) = 0) and
          (GetTickCount64 < Deadline) do
      Sleep(2);
    if (Header.dwFlags and WHDR_DONE) = 0 then
      waveOutReset(GDevice);
  finally
    if GDevice <> 0 then
      waveOutUnprepareHeader(GDevice, @Header, SizeOf(Header));
  end;
  GLastPlayTick := GetTickCount64;
  StartIdleLoop;
end;

procedure PlayTone(AFrequency, ADurationMs: Integer);
var
  Samples: TBytes;
begin
  if (AFrequency <= 0) or (ADurationMs <= 0) then
    Exit;
  AppendSegment(Samples, AFrequency, ADurationMs);
  PlaySamples(Samples, ADurationMs);
end;

procedure PlaySwitchTones(AToRussian: Boolean);
const
  LowHz = 784;
  HighHz = 1175;
  ToneMs = 42;
  GapMs = 26;
var
  Samples: TBytes;
  FirstHz, SecondHz: Integer;
begin
  // One buffer keeps the gap even: a second waveOutOpen would add its own pause.
  if AToRussian then
  begin
    FirstHz := LowHz;
    SecondHz := HighHz;
  end
  else
  begin
    FirstHz := HighHz;
    SecondHz := LowHz;
  end;
  AppendSegment(Samples, FirstHz, ToneMs);
  AppendSegment(Samples, 0, GapMs);
  AppendSegment(Samples, SecondHz, ToneMs);
  PlaySamples(Samples, ToneMs + GapMs + ToneMs);
end;

procedure TSoundWorker.Execute;
var
  SwitchLang: TLangKind;
  DoClick: Boolean;
begin
  while not Terminated do
  begin
    FSignal.WaitFor(250);
    FLock.Acquire;
    try
      SwitchLang := FSwitchLang;
      DoClick := FClickPending;
      FSwitchLang := lkUnknown;
      FClickPending := False;
    finally
      FLock.Release;
    end;
    if SwitchLang <> lkUnknown then
      PlaySwitchTones(SwitchLang = lkRU)
    else if DoClick then
      PlayTone(1800, 12);
    if (GDevice <> 0) and
       (GetTickCount64 - GLastPlayTick > DeviceIdleCloseMs) then
      CloseDevice;
  end;
  CloseDevice;
end;

procedure TSoundWorker.Shutdown;
begin
  FLock.Acquire;
  try
    FShuttingDown := True;
  finally
    FLock.Release;
  end;
  Terminate;
  FSignal.SetEvent;
  WaitFor;
end;

procedure InitializeSound;
begin
  if SoundWorker <> nil then
    Exit;
  SoundWorker := TSoundWorker.Create;
  SoundWorker.Start;
end;

procedure PlaySwitchBeep(ATarget: TLangKind);
begin
  if SoundWorker <> nil then
    SoundWorker.QueueSwitch(ATarget);
end;

procedure PlayKeyClickRU;
begin
  if SoundWorker <> nil then
    SoundWorker.QueueClick;
end;

procedure ShutdownSound;
begin
  if SoundWorker = nil then
    Exit;
  SoundWorker.Shutdown;
  SoundWorker.Free;
  SoundWorker := nil;
end;

initialization
  SoundWorker := nil;
  GDevice := 0;

finalization
  ShutdownSound;

end.
