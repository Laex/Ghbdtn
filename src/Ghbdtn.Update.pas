unit Ghbdtn.Update;

interface

uses
  System.SysUtils;

type
  TUpdateRelease = record
    Tag: string;
    Version: string;
    HtmlUrl: string;
    AssetName: string;
    AssetUrl: string;
    AssetSize: Int64;
    AssetSha256: string;
    ChecksumUrl: string;
  end;

function TryParseVersion(const AText: string;
  out AMajor, AMinor, APatch, ABuild: Integer): Boolean;
function CompareVersions(const ALeft, ARight: string): Integer;
function IsNewerVersion(const ACandidate, ACurrent: string): Boolean;
function ParseLatestReleaseJson(const AJson: string;
  out ARelease: TUpdateRelease): Boolean;
function ParseChecksumText(const AText, AFileName: string): string;
function AppVersionString: string;

{ The replacement process is started while this one still owns the
  single-instance mutex, so it must wait here before creating that mutex. }
procedure WaitForPreviousInstance;
procedure CleanupOldFiles(const AAppDir: string);

{ upQuiet is the marker file alone. --check-update is upInteractive
  even when the marker is also present. }
type
  TUpdatePrompt = (upNone, upQuiet, upInteractive);

function UpdatePromptMode(ASwitch, AMarker: Boolean): TUpdatePrompt;

{ --check-update shows every outcome. Ghbdtn.update next to the executable
  checks quietly: a window appears only when a newer release is available. }
function UpdateCheckRequested: Boolean;
procedure StartUpdateCheck;
procedure CancelUpdateCheck;

implementation

uses
  Winapi.Windows,
  System.Classes,
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.SyncObjs,
  System.Zip,
  Vcl.Forms,
  Ghbdtn.Diagnostics;

const
  cUpdateRepo = 'Laex/Ghbdtn';
  cAssetPrefix = 'Ghbdtn-';
  cAssetSuffix = '-win64.zip';
  cChecksumSuffix = '.sha256';
  cExeName = 'Ghbdtn.exe';
  cStagingDirName = '.update-staging';
  cWaitPidSwitch = '--wait-pid';
  cCheckUpdateSwitch = '--check-update';
  cUpdateMarkerName = 'Ghbdtn.update';

var
  GCheckStarted: Integer;
  GCancel: Integer;

function Cancelled: Boolean;
begin
  Result := TInterlocked.CompareExchange(GCancel, 0, 0) <> 0;
end;

procedure CancelUpdateCheck;
begin
  TInterlocked.Exchange(GCancel, 1);
end;

function TryParseVersion(const AText: string;
  out AMajor, AMinor, APatch, ABuild: Integer): Boolean;
var
  S: string;
  Parts: TArray<string>;
  I, N: Integer;
begin
  Result := False;
  AMajor := 0;
  AMinor := 0;
  APatch := 0;
  ABuild := 0;
  S := Trim(AText);
  if S.StartsWith('v', True) then
    Delete(S, 1, 1);
  if S = '' then
    Exit;
  Parts := S.Split(['.']);
  if (Length(Parts) < 1) or (Length(Parts) > 4) then
    Exit;
  for I := 0 to High(Parts) do
  begin
    if (Parts[I] = '') or not TryStrToInt(Parts[I], N) or (N < 0) then
      Exit;
    case I of
      0: AMajor := N;
      1: AMinor := N;
      2: APatch := N;
      3: ABuild := N;
    end;
  end;
  Result := True;
end;

function CompareVersions(const ALeft, ARight: string): Integer;
var
  L1, L2, L3, L4, R1, R2, R3, R4: Integer;
begin
  if not TryParseVersion(ALeft, L1, L2, L3, L4) or
     not TryParseVersion(ARight, R1, R2, R3, R4) then
    Exit(0);
  if L1 <> R1 then Exit(Ord(L1 > R1) * 2 - 1);
  if L2 <> R2 then Exit(Ord(L2 > R2) * 2 - 1);
  if L3 <> R3 then Exit(Ord(L3 > R3) * 2 - 1);
  if L4 <> R4 then Exit(Ord(L4 > R4) * 2 - 1);
  Result := 0;
end;

function IsNewerVersion(const ACandidate, ACurrent: string): Boolean;
var
  M, N, P, B: Integer;
begin
  Result := TryParseVersion(ACandidate, M, N, P, B) and
    TryParseVersion(ACurrent, M, N, P, B) and
    (CompareVersions(ACandidate, ACurrent) > 0);
end;

function VersionText(AMajor, AMinor, APatch, ABuild: Integer): string;
begin
  Result := Format('%d.%d.%d', [AMajor, AMinor, APatch]);
  if ABuild <> 0 then
    Result := Result + '.' + IntToStr(ABuild);
end;

function FileVersionString(const AExeFile: string): string;
var
  Handle, Size, Len: DWORD;
  Buf: TBytes;
  Info: PVSFixedFileInfo;
begin
  Result := '';
  Handle := 0;
  Size := GetFileVersionInfoSize(PChar(AExeFile), Handle);
  if Size = 0 then
    Exit;
  SetLength(Buf, Size);
  if not GetFileVersionInfo(PChar(AExeFile), 0, Size, @Buf[0]) then
    Exit;
  if not VerQueryValue(@Buf[0], '\', Pointer(Info), Len) or
     (Len < SizeOf(TVSFixedFileInfo)) then
    Exit;
  Result := VersionText(HiWord(Info.dwFileVersionMS), LoWord(Info.dwFileVersionMS),
    HiWord(Info.dwFileVersionLS), LoWord(Info.dwFileVersionLS));
end;

function AppVersionString: string;
begin
  Result := FileVersionString(ParamStr(0));
end;

function ParseLatestReleaseJson(const AJson: string;
  out ARelease: TUpdateRelease): Boolean;
var
  Val: TJSONValue;
  Root, Asset: TJSONObject;
  Assets: TJSONArray;
  I, M, N, P, B: Integer;
  Digest, PackageName, Name: string;
begin
  Result := False;
  ARelease := Default(TUpdateRelease);
  Val := TJSONObject.ParseJSONValue(AJson);
  if Val = nil then
    Exit;
  try
    if not (Val is TJSONObject) then
      Exit;
    Root := TJSONObject(Val);
    if Root.GetValue<Boolean>('draft', False) or
       Root.GetValue<Boolean>('prerelease', False) then
      Exit;
    ARelease.Tag := Root.GetValue<string>('tag_name', '');
    if not TryParseVersion(ARelease.Tag, M, N, P, B) then
      Exit;
    ARelease.Version := VersionText(M, N, P, B);
    ARelease.HtmlUrl := Root.GetValue<string>('html_url', '');
    if not Root.TryGetValue<TJSONArray>('assets', Assets) then
      Exit;
    PackageName := cAssetPrefix + ARelease.Tag + cAssetSuffix;
    for I := 0 to Assets.Count - 1 do
    begin
      if not (Assets.Items[I] is TJSONObject) then
        Continue;
      Asset := TJSONObject(Assets.Items[I]);
      Name := Asset.GetValue<string>('name', '');
      if SameText(Name, PackageName + cChecksumSuffix) then
        ARelease.ChecksumUrl := Asset.GetValue<string>('browser_download_url', '')
      else if SameText(Name, PackageName) then
      begin
        ARelease.AssetName := Name;
        ARelease.AssetUrl := Asset.GetValue<string>('browser_download_url', '');
        ARelease.AssetSize := Asset.GetValue<Int64>('size', 0);
        Digest := Asset.GetValue<string>('digest', '');
        if Digest.StartsWith('sha256:', True) then
          ARelease.AssetSha256 := LowerCase(Copy(Digest, 8, MaxInt));
      end;
    end;
    Result := ARelease.AssetUrl <> '';
  finally
    Val.Free;
  end;
end;

{ Accepts "<64 hex>" or "<64 hex> *<file>" lines (sha256sum format). When the
  text names several files, the line for AFileName is used. }
function ParseChecksumText(const AText, AFileName: string): string;
var
  Line, Hash, Rest: string;
  Lines: TArray<string>;
  I: Integer;
  Ok: Boolean;
begin
  Result := '';
  Lines := AText.Replace(#13, '').Split([#10]);
  for Line in Lines do
  begin
    Hash := Trim(Line);
    if Length(Hash) < 64 then
      Continue;
    Rest := Trim(Copy(Hash, 65, MaxInt));
    Hash := LowerCase(Copy(Hash, 1, 64));
    Ok := True;
    for I := 1 to 64 do
      if not CharInSet(Hash[I], ['0'..'9', 'a'..'f']) then
        Ok := False;
    if not Ok then
      Continue;
    if Rest.StartsWith('*') then
      Rest := Copy(Rest, 2, MaxInt);
    if (Rest = '') or SameText(ExtractFileName(Rest), AFileName) then
      Exit(Hash);
  end;
end;

function NewHttpClient(AResponseTimeoutMs: Integer): THTTPClient;
begin
  Result := THTTPClient.Create;
  Result.UserAgent := 'Ghbdtn';
  if AppVersionString <> '' then
    Result.UserAgent := Result.UserAgent + '/' + AppVersionString;
  Result.ConnectionTimeout := 15000;
  Result.ResponseTimeout := AResponseTimeoutMs;
  Result.HandleRedirects := True;
end;

function FetchLatestRelease(out ARelease: TUpdateRelease; out AError: string): Boolean;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
  Url: string;
begin
  Result := False;
  AError := '';
  ARelease := Default(TUpdateRelease);
  Url := Format('https://api.github.com/repos/%s/releases/latest', [cUpdateRepo]);
  Http := NewHttpClient(20000);
  try
    try
      Resp := Http.Get(Url, nil,
        [TNetHeader.Create('Accept', 'application/vnd.github+json')]);
      if Resp.StatusCode <> 200 then
      begin
        AError := Format('GitHub: HTTP %d', [Resp.StatusCode]);
        Exit;
      end;
      Result := ParseLatestReleaseJson(Resp.ContentAsString(TEncoding.UTF8), ARelease);
      if not Result then
        AError := 'GitHub: no suitable release package';
    except
      on E: Exception do
        AError := E.Message;
    end;
  finally
    Http.Free;
  end;
end;

function FileSha256(const AFileName: string): string;
begin
  Result := LowerCase(THashSHA2.GetHashStringFromFile(AFileName, SHA256));
end;

function FetchChecksum(const ARelease: TUpdateRelease; out AHash,
  AError: string): Boolean;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
begin
  AHash := ARelease.AssetSha256;
  AError := '';
  if AHash <> '' then
    Exit(True);
  if ARelease.ChecksumUrl <> '' then
  begin
    Http := NewHttpClient(20000);
    try
      try
        Resp := Http.Get(ARelease.ChecksumUrl);
        if Resp.StatusCode = 200 then
          AHash := ParseChecksumText(Resp.ContentAsString(TEncoding.UTF8),
            ARelease.AssetName);
      except
        on E: Exception do
          AError := E.Message;
      end;
    finally
      Http.Free;
    end;
  end;
  Result := AHash <> '';
  if not Result and (AError = '') then
    AError := 'no checksum published for the release package';
end;

function DownloadAsset(const ARelease: TUpdateRelease;
  const AExpectedSha256, ADestFile: string; out AError: string): Boolean;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
  Stream: TFileStream;
  Actual: string;
begin
  AError := '';
  ForceDirectories(ExtractFileDir(ADestFile));
  Http := NewHttpClient(120000);
  try
    Stream := TFileStream.Create(ADestFile, fmCreate);
    try
      try
        Resp := Http.Get(ARelease.AssetUrl, Stream);
        if Resp.StatusCode <> 200 then
          AError := Format('HTTP %d', [Resp.StatusCode]);
      except
        on E: Exception do
          AError := E.Message;
      end;
    finally
      Stream.Free;
    end;
  finally
    Http.Free;
  end;
  if (AError = '') and not Cancelled then
  begin
    Actual := FileSha256(ADestFile);
    if not SameText(Actual, AExpectedSha256) then
      AError := 'sha256 mismatch'
    else if (ARelease.AssetSize > 0) and (TFile.GetSize(ADestFile) <> ARelease.AssetSize) then
      AError := 'size mismatch';
  end;
  Result := (AError = '') and not Cancelled;
  if not Result then
    System.SysUtils.DeleteFile(ADestFile);
end;

function ExtractUpdate(const AZipFile, AStagingDir: string; out AError: string): Boolean;
var
  Zip: TZipFile;
  I: Integer;
  Name, Full, Root: string;
begin
  Result := False;
  AError := '';
  try
    if TDirectory.Exists(AStagingDir) then
      TDirectory.Delete(AStagingDir, True);
    ForceDirectories(AStagingDir);
    Root := IncludeTrailingPathDelimiter(TPath.GetFullPath(AStagingDir));
    Zip := TZipFile.Create;
    try
      Zip.Open(AZipFile, zmRead);
      for I := 0 to Zip.FileCount - 1 do
      begin
        Name := StringReplace(Zip.FileNames[I], '/', PathDelim, [rfReplaceAll]);
        Full := TPath.GetFullPath(TPath.Combine(Root, Name));
        if not Full.StartsWith(Root, True) then
        begin
          AError := 'unsafe path in package: ' + Zip.FileNames[I];
          Exit;
        end;
      end;
      Zip.ExtractAll(AStagingDir);
    finally
      Zip.Free;
    end;
    if not TFile.Exists(TPath.Combine(AStagingDir, cExeName)) then
    begin
      AError := 'package has no ' + cExeName;
      Exit;
    end;
    Result := True;
  except
    on E: Exception do
      AError := E.Message;
  end;
  if not Result and TDirectory.Exists(AStagingDir) then
    try
      TDirectory.Delete(AStagingDir, True);
    except
      // leftover staging is removed on the next start
    end;
end;

type
  TAppliedFile = record
    Target: string;
    Backup: string;
  end;

function FreeBackupName(const ATarget: string): string;
var
  N: Integer;
begin
  Result := ATarget + '.old';
  if not FileExists(Result) or System.SysUtils.DeleteFile(Result) then
    Exit;
  // The previous backup can still be mapped by the process that loaded it.
  for N := 1 to 99 do
  begin
    Result := ATarget + '.old' + IntToStr(N);
    if not FileExists(Result) or System.SysUtils.DeleteFile(Result) then
      Exit;
  end;
  Result := '';
end;

function ApplyStagedUpdate(const AStagingDir, AAppDir: string; out AError: string): Boolean;
var
  Files: TArray<string>;
  Done: TArray<TAppliedFile>;
  Src, Rel, Root: string;
  Item: TAppliedFile;
  I: Integer;
begin
  Result := False;
  AError := '';
  Root := IncludeTrailingPathDelimiter(TPath.GetFullPath(AStagingDir));
  Files := TDirectory.GetFiles(AStagingDir, '*', TSearchOption.soAllDirectories);
  SetLength(Done, 0);
  try
    for Src in Files do
    begin
      if Cancelled then
      begin
        AError := '';
        Exit;
      end;
      Rel := Copy(TPath.GetFullPath(Src), Length(Root) + 1, MaxInt);
      Item.Target := TPath.Combine(AAppDir, Rel);
      Item.Backup := '';
      ForceDirectories(ExtractFileDir(Item.Target));
      if FileExists(Item.Target) then
      begin
        Item.Backup := FreeBackupName(Item.Target);
        if (Item.Backup = '') or
           not MoveFileEx(PChar(Item.Target), PChar(Item.Backup), 0) then
        begin
          AError := Format('%s: %s', [Rel, SysErrorMessage(GetLastError)]);
          Exit;
        end;
      end;
      if not MoveFileEx(PChar(Src), PChar(Item.Target),
        MOVEFILE_REPLACE_EXISTING or MOVEFILE_COPY_ALLOWED) then
      begin
        AError := Format('%s: %s', [Rel, SysErrorMessage(GetLastError)]);
        if Item.Backup <> '' then
          MoveFileEx(PChar(Item.Backup), PChar(Item.Target), 0);
        Exit;
      end;
      SetLength(Done, Length(Done) + 1);
      Done[High(Done)] := Item;
    end;
    Result := True;
  finally
    if not Result then
    begin
      for I := High(Done) downto 0 do
      begin
        System.SysUtils.DeleteFile(Done[I].Target);
        if Done[I].Backup <> '' then
          MoveFileEx(PChar(Done[I].Backup), PChar(Done[I].Target), 0);
      end;
    end
    else
      try
        TDirectory.Delete(AStagingDir, True);
      except
        // leftover staging is removed on the next start
      end;
  end;
end;

function AppDir: string;
begin
  Result := ExtractFileDir(ParamStr(0));
end;

function StagingDir: string;
begin
  Result := TPath.Combine(AppDir, cStagingDirName);
end;

function RestartApplication(const AExeFile: string; out AError: string): Boolean;
var
  Cmd: string;
  Si: TStartupInfo;
  Pi: TProcessInformation;
begin
  AError := '';
  Cmd := Format('"%s" %s %d', [AExeFile, cWaitPidSwitch, GetCurrentProcessId]);
  UniqueString(Cmd);
  ZeroMemory(@Si, SizeOf(Si));
  Si.cb := SizeOf(Si);
  Result := CreateProcess(nil, PChar(Cmd), nil, nil, False, 0, nil,
    PChar(ExtractFileDir(AExeFile)), Si, Pi);
  if Result then
  begin
    CloseHandle(Pi.hThread);
    CloseHandle(Pi.hProcess);
  end
  else
    AError := SysErrorMessage(GetLastError);
end;

function InstallRelease(const ARelease: TUpdateRelease; out AError: string): Boolean;
var
  ZipFile, ExpectedSha256: string;
begin
  Result := False;
  AError := '';
  // An update without a published checksum is never installed.
  if not FetchChecksum(ARelease, ExpectedSha256, AError) then
    Exit;
  ZipFile := TPath.Combine(TPath.GetTempPath,
    'Ghbdtn-' + IntToStr(GetCurrentProcessId) + '.zip');
  try
    if not DownloadAsset(ARelease, ExpectedSha256, ZipFile, AError) then
      Exit;
    if Cancelled then
      Exit;
    if not ExtractUpdate(ZipFile, StagingDir, AError) then
      Exit;
    if Cancelled then
      Exit;
    if not ApplyStagedUpdate(StagingDir, AppDir, AError) then
      Exit;
    if Cancelled then
      Exit;
    Result := RestartApplication(ParamStr(0), AError);
    if not Result then
      AError := 'Файлы обновлены, но перезапуск не удался: ' + AError;
  finally
    System.SysUtils.DeleteFile(ZipFile);
  end;
end;

procedure CleanupOldFiles(const AAppDir: string);
var
  F, Suffix: string;
  P, N: Integer;
begin
  if not TDirectory.Exists(AAppDir) then
    Exit;
  try
    for F in TDirectory.GetFiles(AAppDir, '*.old*', TSearchOption.soTopDirectoryOnly) do
    begin
      P := F.LastIndexOf('.old');
      if P <= 0 then
        Continue;
      Suffix := Copy(F, P + 5, MaxInt);
      if (Suffix <> '') and not TryStrToInt(Suffix, N) then
        Continue;
      if FileExists(Copy(F, 1, P)) then
        System.SysUtils.DeleteFile(F);
    end;
    if TDirectory.Exists(TPath.Combine(AAppDir, cStagingDirName)) then
      TDirectory.Delete(TPath.Combine(AAppDir, cStagingDirName), True);
  except
    // best effort: a locked backup can be removed on the next start
  end;
end;

procedure WaitForPreviousInstance;
var
  I: Integer;
  Pid: Cardinal;
  H: THandle;
begin
  for I := 1 to ParamCount - 1 do
    if SameText(ParamStr(I), cWaitPidSwitch) and
       TryStrToUInt(ParamStr(I + 1), Pid) and (Pid <> 0) then
    begin
      H := OpenProcess(SYNCHRONIZE, False, Pid);
      if H <> 0 then
      begin
        WaitForSingleObject(H, 30000);
        CloseHandle(H);
      end;
      Exit;
    end;
end;

function SwitchPresent(const ASwitch: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), ASwitch) then
      Exit(True);
  Result := False;
end;

function UpdateSwitchRequested: Boolean;
begin
  Result := SwitchPresent(cCheckUpdateSwitch);
end;

function UpdateMarkerPresent: Boolean;
begin
  Result := TFile.Exists(TPath.Combine(ExtractFileDir(ParamStr(0)),
    cUpdateMarkerName));
end;

function UpdatePromptMode(ASwitch, AMarker: Boolean): TUpdatePrompt;
begin
  if ASwitch then
    Exit(upInteractive);
  if AMarker then
    Exit(upQuiet);
  Result := upNone;
end;

function UpdateCheckRequested: Boolean;
begin
  Result := UpdatePromptMode(UpdateSwitchRequested, UpdateMarkerPresent) <> upNone;
end;

function SingleLine(const AText: string): string;
begin
  Result := StringReplace(StringReplace(AText, #13, ' ', [rfReplaceAll]),
    #10, ' ', [rfReplaceAll]);
end;

procedure ShowUpdateMessage(const AText: string; AFlags: UINT);
begin
  TThread.Queue(nil,
    procedure
    begin
      if Cancelled or (AText = '') then
        Exit;
      Application.MessageBox(PChar(AText), 'Ghbdtn',
        MB_OK or AFlags or MB_SETFOREGROUND);
    end);
end;

procedure StartUpdateCheck;
var
  Interactive: Boolean;
begin
  Interactive := UpdatePromptMode(UpdateSwitchRequested,
    UpdateMarkerPresent) = upInteractive;
  if not UpdateCheckRequested then
    Exit;
  if AppVersionString = '' then
    Exit;
  if TInterlocked.CompareExchange(GCheckStarted, 1, 0) <> 0 then
    Exit;
  with TThread.CreateAnonymousThread(
    procedure
    var
      Release: TUpdateRelease;
      Error: string;
      Accept: Integer;
      Current, Text: string;
    begin
      try
        if Cancelled then
          Exit;
        if not FetchLatestRelease(Release, Error) then
        begin
          if Interactive then
            ShowUpdateMessage('Не удалось проверить обновления.' + sLineBreak +
              Error, MB_ICONERROR)
          else
            LogDiagnostic(dlError, deUpdateCheckFailed, 0, SingleLine(Error));
          Exit;
        end;
        if not IsNewerVersion(Release.Version, AppVersionString) then
        begin
          if Interactive then
            ShowUpdateMessage('Установлена последняя версия (' +
              AppVersionString + ').', MB_ICONINFORMATION)
          else
            LogDiagnostic(dlError, deUpdateCurrent, 0, AppVersionString);
          Exit;
        end;
        if Cancelled then
          Exit;
        Accept := 0;
        Current := AppVersionString;
        Text := Format('Доступна версия %s (сейчас %s).' + sLineBreak +
          'Обновить и перезапустить?', [Release.Version, Current]);
        TThread.Synchronize(nil,
          procedure
          begin
            if Cancelled then
              Exit;
            if Application.MessageBox(PChar(Text), 'Ghbdtn',
              MB_YESNO or MB_ICONQUESTION or MB_SETFOREGROUND) = IDYES then
              Accept := 1;
          end);
        if (Accept = 0) or Cancelled then
          Exit;
        if not InstallRelease(Release, Error) then
        begin
          if not Cancelled then
            ShowUpdateMessage('Не удалось обновить.' + sLineBreak + Error,
              MB_ICONERROR);
          Exit;
        end;
        TThread.Queue(nil,
          procedure
          begin
            if not Cancelled then
              Application.Terminate;
          end);
      except
        // The check must not take the process down.
        on E: Exception do
          if not Interactive then
            LogDiagnostic(dlError, deUpdateCheckFailed, 0, SingleLine(E.Message));
      end;
    end) do
  begin
    FreeOnTerminate := True;
    Start;
  end;
end;

end.
