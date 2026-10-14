unit Ghbdtn.Clipboard;

interface

uses
  Winapi.Windows,
  System.SysUtils;

type
  TClipboardFormatData = record
    Format: UINT;
    Bytes: TBytes;
  end;

  TClipboardSnapshot = record
    Items: TArray<TClipboardFormatData>;
  end;

  TClipboardCaptureResult = (ccOk, ccUnavailable, ccUnsupported, ccTooLarge);

function OpenClipboardWithRetry: Boolean;
function TryPeekClipboardText(out AText: string; AMaxChars: NativeUInt;
  out ATruncated: Boolean): Boolean;
function TryWriteClipboardText(const AText: string): Boolean;
function TryClearClipboard: Boolean;
function ClipboardSequence: DWORD;
function ClipboardHoldsText(const AText: string): Boolean;

{ Copies every format on the clipboard. The capture is refused (and nothing is
  changed) when some format cannot be copied as plain bytes, such as a GDI
  handle without a DIB, or when the content is larger than the size cap, so
  the caller never clears a clipboard it cannot put back. }
function TryCaptureClipboard(out ASnapshot: TClipboardSnapshot;
  out AResult: TClipboardCaptureResult): Boolean;
function TryRestoreClipboard(const ASnapshot: TClipboardSnapshot): Boolean;

implementation

uses
  Ghbdtn.Diagnostics;

const
  ClipboardRetryCount = 8;
  ClipboardRetryDelayMs = 15;
  MaxSnapshotBytes = 64 * 1024 * 1024;
  MaxSnapshotFormats = 64;
  CF_DSPFIRST = $0080;
  CF_DSPLAST = $008E;

function OpenClipboardWithRetry: Boolean;
var
  Attempt: Integer;
begin
  for Attempt := 1 to ClipboardRetryCount do
  begin
    if OpenClipboard(0) then
      Exit(True);
    Sleep(ClipboardRetryDelayMs);
  end;
  Result := False;
end;

function ClipboardSequence: DWORD;
begin
  Result := GetClipboardSequenceNumber;
end;

function ClipboardHandleToString(Data: THandle; AMaxChars: NativeUInt;
  out ATruncated: Boolean): string;
var
  Ptr: PWideChar;
  Available: NativeUInt;
  Len: NativeUInt;
begin
  Result := '';
  ATruncated := False;
  Ptr := GlobalLock(Data);
  if Ptr = nil then
    Exit;
  try
    Available := GlobalSize(Data) div SizeOf(WideChar);
    if Available = 0 then
      Exit;
    if Available > AMaxChars + 1 then
      Available := AMaxChars + 1;
    Len := 0;
    while (Len < Available) and (Ptr[Len] <> #0) do
      Inc(Len);
    if Len > AMaxChars then
    begin
      Len := AMaxChars;
      ATruncated := True;
    end;
    SetString(Result, Ptr, Len);
  finally
    GlobalUnlock(Data);
  end;
end;

function ClipboardHoldsText(const AText: string): Boolean;
var
  Data: THandle;
  Truncated: Boolean;
begin
  Result := False;
  if not OpenClipboardWithRetry then
    Exit;
  try
    Data := GetClipboardData(CF_UNICODETEXT);
    if Data <> 0 then
      Result := ClipboardHandleToString(Data, Length(AText) + 1,
        Truncated) = AText;
  finally
    CloseClipboard;
  end;
end;

{ One attempt, no log: callers poll this while an application is still
  filling the clipboard. ATruncated is set when the clipboard text is longer
  than AMaxChars. A truncated selection must not be pasted back: the paste
  would replace the whole selection with only its head. }
function TryPeekClipboardText(out AText: string; AMaxChars: NativeUInt;
  out ATruncated: Boolean): Boolean;
var
  Data: THandle;
begin
  AText := '';
  ATruncated := False;
  Result := False;
  if not OpenClipboard(0) then
    Exit;
  try
    Data := GetClipboardData(CF_UNICODETEXT);
    if Data <> 0 then
    begin
      AText := ClipboardHandleToString(Data, AMaxChars, ATruncated);
      Result := AText <> '';
    end;
  finally
    CloseClipboard;
  end;
end;

function TryWriteClipboardText(const AText: string): Boolean;
var
  Attempt: Integer;
  Data: THandle;
  Ptr: Pointer;
  ByteCount: NativeUInt;
  Text: string;
begin
  Text := AText;
  for Attempt := 1 to ClipboardRetryCount do
  begin
    ByteCount := (Length(Text) + 1) * SizeOf(WideChar);
    Data := GlobalAlloc(GMEM_MOVEABLE, ByteCount);
    if Data = 0 then
      Continue;
    Ptr := GlobalLock(Data);
    if Ptr = nil then
    begin
      GlobalFree(Data);
      Continue;
    end;
    try
      if Text <> '' then
        Move(PWideChar(Text)^, Ptr^, ByteCount)
      else
        PWideChar(Ptr)^ := #0;
    finally
      GlobalUnlock(Data);
    end;

    if OpenClipboardWithRetry then
    try
      EmptyClipboard;
      if SetClipboardData(CF_UNICODETEXT, Data) <> 0 then
      begin
        Data := 0;
        Exit(True);
      end;
    finally
      CloseClipboard;
      if Data <> 0 then
        GlobalFree(Data);
    end
    else
      GlobalFree(Data);

    Sleep(ClipboardRetryDelayMs);
  end;
  LogDiagnostic(dlError, deClipboardWriteFailed);
  Result := False;
end;

function TryClearClipboard: Boolean;
begin
  Result := False;
  if not OpenClipboardWithRetry then
    Exit;
  try
    EmptyClipboard;
    Result := True;
  finally
    CloseClipboard;
  end;
end;

function IsGdiOrPrivateFormat(AFormat: UINT): Boolean;
begin
  Result := (AFormat = CF_METAFILEPICT) or (AFormat = CF_ENHMETAFILE) or
    (AFormat = CF_OWNERDISPLAY) or
    ((AFormat >= CF_DSPFIRST) and (AFormat <= CF_DSPLAST)) or
    ((AFormat >= CF_GDIOBJFIRST) and (AFormat <= CF_GDIOBJLAST)) or
    ((AFormat >= CF_PRIVATEFIRST) and (AFormat <= CF_PRIVATELAST));
end;

function TryCaptureClipboardOpen(out ASnapshot: TClipboardSnapshot;
  out AResult: TClipboardCaptureResult): Boolean;
var
  Formats: TArray<UINT>;
  Format: UINT;
  Data: THandle;
  Ptr: Pointer;
  Size: NativeUInt;
  Total: UInt64;
  HasDib, HasBitmapOnly: Boolean;
  Count, I: Integer;
begin
  Result := False;
  ASnapshot.Items := nil;
  AResult := ccOk;
  SetLength(Formats, 0);
  Format := EnumClipboardFormats(0);
  while Format <> 0 do
  begin
    if Length(Formats) >= MaxSnapshotFormats then
    begin
      AResult := ccUnsupported;
      Exit;
    end;
    SetLength(Formats, Length(Formats) + 1);
    Formats[High(Formats)] := Format;
    Format := EnumClipboardFormats(Format);
  end;

  HasDib := False;
  for I := 0 to High(Formats) do
    if (Formats[I] = CF_DIB) or (Formats[I] = CF_DIBV5) then
      HasDib := True;

  SetLength(ASnapshot.Items, Length(Formats));
  Count := 0;
  Total := 0;
  for I := 0 to High(Formats) do
  begin
    Format := Formats[I];
    // CF_BITMAP and CF_PALETTE are GDI handles that Windows rebuilds from a
    // DIB; without one they cannot be copied.
    HasBitmapOnly := (Format = CF_BITMAP) or (Format = CF_PALETTE);
    if HasBitmapOnly and HasDib then
      Continue;
    if HasBitmapOnly or IsGdiOrPrivateFormat(Format) then
    begin
      AResult := ccUnsupported;
      Exit;
    end;
    Data := GetClipboardData(Format);
    if Data = 0 then
    begin
      AResult := ccUnsupported;
      Exit;
    end;
    Size := GlobalSize(Data);
    if Size = 0 then
    begin
      AResult := ccUnsupported;
      Exit;
    end;
    Inc(Total, Size);
    if Total > MaxSnapshotBytes then
    begin
      AResult := ccTooLarge;
      Exit;
    end;
    Ptr := GlobalLock(Data);
    if Ptr = nil then
    begin
      AResult := ccUnsupported;
      Exit;
    end;
    try
      SetLength(ASnapshot.Items[Count].Bytes, Size);
      Move(Ptr^, ASnapshot.Items[Count].Bytes[0], Size);
    finally
      GlobalUnlock(Data);
    end;
    ASnapshot.Items[Count].Format := Format;
    Inc(Count);
  end;
  SetLength(ASnapshot.Items, Count);
  Result := True;
end;

function TryCaptureClipboard(out ASnapshot: TClipboardSnapshot;
  out AResult: TClipboardCaptureResult): Boolean;
begin
  ASnapshot.Items := nil;
  AResult := ccUnavailable;
  if not OpenClipboardWithRetry then
  begin
    LogDiagnostic(dlError, deClipboardSnapshotFailed);
    Exit(False);
  end;
  try
    Result := TryCaptureClipboardOpen(ASnapshot, AResult);
  finally
    CloseClipboard;
  end;
  if not Result then
  begin
    ASnapshot.Items := nil;
    LogDiagnostic(dlError, deClipboardSnapshotFailed);
  end;
end;

function TryRestoreClipboard(const ASnapshot: TClipboardSnapshot): Boolean;
var
  Item: TClipboardFormatData;
  Data: THandle;
  Ptr: Pointer;
begin
  Result := False;
  if not OpenClipboardWithRetry then
  begin
    LogDiagnostic(dlError, deClipboardRestoreFailed);
    Exit;
  end;
  try
    EmptyClipboard;
    Result := True;
    for Item in ASnapshot.Items do
    begin
      Data := GlobalAlloc(GMEM_MOVEABLE, Length(Item.Bytes));
      if Data = 0 then
      begin
        Result := False;
        Continue;
      end;
      Ptr := GlobalLock(Data);
      if Ptr = nil then
      begin
        GlobalFree(Data);
        Result := False;
        Continue;
      end;
      try
        Move(Item.Bytes[0], Ptr^, Length(Item.Bytes));
      finally
        GlobalUnlock(Data);
      end;
      if SetClipboardData(Item.Format, Data) = 0 then
      begin
        GlobalFree(Data);
        Result := False;
      end;
    end;
  finally
    CloseClipboard;
  end;
  if not Result then
    LogDiagnostic(dlError, deClipboardRestoreFailed);
end;

end.
