unit Ghbdtn.InputQueue;

interface

uses
  Winapi.Windows,
  System.Generics.Collections,
  System.SyncObjs,
  Ghbdtn.Analyzer,
  Ghbdtn.Layout,
  Ghbdtn.Learning,
  Ghbdtn.Translit;

type
  TInputWorkKind = (iwReplaceWord, iwReplaceSelection, iwReplaceBeforeCaret,
    iwSwitchLayout, iwPersistSettings);

  TInputWorkItem = record
    Kind: TInputWorkKind;
    TargetWindow: HWND;
    OldWordLength: Integer;
    NewText: string;
    ExpectedText: string;
    TargetLang: TLangKind;
    TrailingKey: Word;
    PlaySwitchSound: Boolean;
    LearningWord: string;
    LearningProcess: string;
    LearningAction: TLearningAction;
    FromCaret: Boolean;
    CaseCycle: Boolean;
    KeepLayout: Boolean;
    ToggleCapsLock: Boolean;
    CaseMode: TCaseMode;
    Translit: TTranslitDirection;
    ActivateTarget: Boolean;
    SwitchLayoutAfter: Boolean;
    TargetFocus: HWND;
    EnqueuedTick: UInt64;
  end;

  TQueuedInput = record
    VirtualKey: Word;
    ScanCode: Word;
    Flags: DWORD;
  end;

{ A queued replacement is applied only to the control it was prepared for and
  only shortly after it was queued; otherwise the text under the caret is no
  longer the text it was computed from. }
function IsWorkItemCurrent(AItemFocus, ACurrentFocus: HWND;
  AEnqueuedTick, ANow: UInt64): Boolean;

const
  MaxWorkItemAgeMs = 3000;

type
  TInputQueue = class
  private
    FLock: TCriticalSection;
    FSignal: TEvent;
    FWork: TQueue<TInputWorkItem>;
    FBackground: TQueue<TInputWorkItem>;
    FReplay: TQueue<TQueuedInput>;
    // Arrival order of the work and replay items, so a replacement waits for
    // the keys typed before it and not for those typed after it.
    FWorkOrder: TQueue<UInt64>;
    FReplayOrder: TQueue<UInt64>;
    FArrivals: UInt64;
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

function IsWorkItemCurrent(AItemFocus, ACurrentFocus: HWND;
  AEnqueuedTick, ANow: UInt64): Boolean;
begin
  if (AItemFocus <> 0) and (ACurrentFocus <> 0) and
     (AItemFocus <> ACurrentFocus) then
    Exit(False);
  Result := (AEnqueuedTick = 0) or (ANow < AEnqueuedTick) or
    (ANow - AEnqueuedTick <= MaxWorkItemAgeMs);
end;

constructor TInputQueue.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FSignal := TEvent.Create(nil, False, False, '');
  FWork := TQueue<TInputWorkItem>.Create;
  FBackground := TQueue<TInputWorkItem>.Create;
  FReplay := TQueue<TQueuedInput>.Create;
  FWorkOrder := TQueue<UInt64>.Create;
  FReplayOrder := TQueue<UInt64>.Create;
end;

destructor TInputQueue.Destroy;
begin
  FReplayOrder.Free;
  FWorkOrder.Free;
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
      Inc(FArrivals);
      FWorkOrder.Enqueue(FArrivals);
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
    Inc(FArrivals);
    FReplayOrder.Enqueue(FArrivals);
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
    begin
      FReplay.Enqueue(AInput);
      Inc(FArrivals);
      FReplayOrder.Enqueue(FArrivals);
    end;
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
    Result := (FWork.Count > 0) and
      ((FReplay.Count = 0) or (FWorkOrder.Peek < FReplayOrder.Peek));
    if Result then
    begin
      AItem := FWork.Dequeue;
      FWorkOrder.Dequeue;
    end;
  finally
    FLock.Release;
  end;
end;

function TInputQueue.TryDequeueReplay(out AInput: TQueuedInput): Boolean;
begin
  FLock.Acquire;
  try
    Result := (FReplay.Count > 0) and
      ((FWork.Count = 0) or (FReplayOrder.Peek < FWorkOrder.Peek));
    if Result then
    begin
      AInput := FReplay.Dequeue;
      FReplayOrder.Dequeue;
    end;
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
