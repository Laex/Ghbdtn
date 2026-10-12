unit Ghbdtn.InputQueue;

interface

uses
  Winapi.Windows,
  System.Generics.Collections,
  System.SyncObjs,
  Ghbdtn.Layout,
  Ghbdtn.Learning;

type
  TInputWorkKind = (iwReplaceWord, iwReplaceSelection, iwSwitchLayout,
    iwPersistSettings);

  TInputWorkItem = record
    Kind: TInputWorkKind;
    TargetWindow: HWND;
    OldWordLength: Integer;
    NewText: string;
    TargetLang: TLangKind;
    TrailingKey: Word;
    PlaySwitchSound: Boolean;
    LearningWord: string;
    LearningProcess: string;
    LearningAction: TLearningAction;
    FromCaret: Boolean;
    CaseCycle: Boolean;
  end;

  TQueuedInput = record
    VirtualKey: Word;
    ScanCode: Word;
    Flags: DWORD;
  end;

  TInputQueue = class
  private
    FLock: TCriticalSection;
    FSignal: TEvent;
    FWork: TQueue<TInputWorkItem>;
    FBackground: TQueue<TInputWorkItem>;
    FReplay: TQueue<TQueuedInput>;
    FReplacementPending: Boolean;
    FStopping: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure EnqueueWork(const AItem: TInputWorkItem);
    procedure EnqueueReplay(const AInput: TQueuedInput);
    function TryCaptureReplay(const AInput: TQueuedInput): Boolean;
    function TryDequeueWork(out AItem: TInputWorkItem): Boolean;
    function TryDequeueBackground(out AItem: TInputWorkItem): Boolean;
    function TryDequeueReplay(out AInput: TQueuedInput): Boolean;
    function TryCompleteIfIdle: Boolean;
    procedure Stop;
    function WaitForWork(ATimeout: Cardinal): TWaitResult;
    function IsReplacementPending: Boolean;
    function IsStopping: Boolean;
  end;

implementation

constructor TInputQueue.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FSignal := TEvent.Create(nil, False, False, '');
  FWork := TQueue<TInputWorkItem>.Create;
  FBackground := TQueue<TInputWorkItem>.Create;
  FReplay := TQueue<TQueuedInput>.Create;
end;

destructor TInputQueue.Destroy;
begin
  FReplay.Free;
  FBackground.Free;
  FWork.Free;
  FSignal.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TInputQueue.EnqueueWork(const AItem: TInputWorkItem);
begin
  FLock.Acquire;
  try
    if AItem.Kind = iwPersistSettings then
      FBackground.Enqueue(AItem)
    else
    begin
      FWork.Enqueue(AItem);
      FReplacementPending := True;
    end;
  finally
    FLock.Release;
  end;
  FSignal.SetEvent;
end;

function TInputQueue.TryDequeueBackground(
  out AItem: TInputWorkItem): Boolean;
begin
  FLock.Acquire;
  try
    Result := FBackground.Count > 0;
    if Result then
      AItem := FBackground.Dequeue;
  finally
    FLock.Release;
  end;
end;

procedure TInputQueue.EnqueueReplay(const AInput: TQueuedInput);
begin
  FLock.Acquire;
  try
    FReplay.Enqueue(AInput);
  finally
    FLock.Release;
  end;
  FSignal.SetEvent;
end;

function TInputQueue.TryCaptureReplay(const AInput: TQueuedInput): Boolean;
begin
  FLock.Acquire;
  try
    Result := FReplacementPending and not FStopping;
    if Result then
      FReplay.Enqueue(AInput);
  finally
    FLock.Release;
  end;
  if Result then
    FSignal.SetEvent;
end;

function TInputQueue.TryDequeueWork(out AItem: TInputWorkItem): Boolean;
begin
  FLock.Acquire;
  try
    Result := FWork.Count > 0;
    if Result then
      AItem := FWork.Dequeue;
  finally
    FLock.Release;
  end;
end;

function TInputQueue.TryDequeueReplay(out AInput: TQueuedInput): Boolean;
begin
  FLock.Acquire;
  try
    Result := FReplay.Count > 0;
    if Result then
      AInput := FReplay.Dequeue;
  finally
    FLock.Release;
  end;
end;

function TInputQueue.TryCompleteIfIdle: Boolean;
begin
  FLock.Acquire;
  try
    Result := (FWork.Count = 0) and (FReplay.Count = 0);
    if Result then
      FReplacementPending := False;
  finally
    FLock.Release;
  end;
end;

procedure TInputQueue.Stop;
begin
  FLock.Acquire;
  try
    FStopping := True;
  finally
    FLock.Release;
  end;
  FSignal.SetEvent;
end;

function TInputQueue.WaitForWork(ATimeout: Cardinal): TWaitResult;
begin
  Result := FSignal.WaitFor(ATimeout);
end;

function TInputQueue.IsReplacementPending: Boolean;
begin
  FLock.Acquire;
  try
    Result := FReplacementPending;
  finally
    FLock.Release;
  end;
end;

function TInputQueue.IsStopping: Boolean;
begin
  FLock.Acquire;
  try
    Result := FStopping;
  finally
    FLock.Release;
  end;
end;

end.
