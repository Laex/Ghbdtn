unit Ghbdtn.Phrase;

interface

uses
  Ghbdtn.Layout;

const
  PhraseWindow = 5;
  PhraseBiasCap = 3;

type
  TPhraseContext = record
    Languages: array[0..PhraseWindow - 1] of TLangKind;
    Count: Integer;
    // True when the words before the current one are not tracked at all,
    // as for a selection converted by hand.
    Untracked: Boolean;
  end;

function EmptyPhrase: TPhraseContext;
function UntrackedPhrase: TPhraseContext;
function PhraseEndsWith(const AContext: TPhraseContext;
  ALang: TLangKind): Boolean;
function ContainsPhraseLetter(const AText: string): Boolean;
procedure RememberPhraseLanguage(var AContext: TPhraseContext; ALang: TLangKind);
function PhraseScoreBias(const AContext: TPhraseContext; ALang: TLangKind): Integer;

implementation

uses
  System.SysUtils;

function EmptyPhrase: TPhraseContext;
begin
  Result := Default(TPhraseContext);
end;

function UntrackedPhrase: TPhraseContext;
begin
  Result := Default(TPhraseContext);
  Result.Untracked := True;
end;

function PhraseEndsWith(const AContext: TPhraseContext;
  ALang: TLangKind): Boolean;
begin
  Result := (AContext.Count > 0) and
    (AContext.Languages[AContext.Count - 1] = ALang);
end;

function ContainsPhraseLetter(const AText: string): Boolean;
var
  I: Integer;
  C: Char;
begin
  for I := 1 to Length(AText) do
  begin
    C := AText[I];
    if CharInSet(C, ['a'..'z', 'A'..'Z']) or
       ((C >= 'А') and (C <= 'я')) or (C = 'Ё') or (C = 'ё') then
      Exit(True);
  end;
  Result := False;
end;

procedure RememberPhraseLanguage(var AContext: TPhraseContext; ALang: TLangKind);
var
  I: Integer;
begin
  if ALang = lkUnknown then
    Exit;
  if AContext.Count < PhraseWindow then
  begin
    AContext.Languages[AContext.Count] := ALang;
    Inc(AContext.Count);
    Exit;
  end;
  for I := 1 to PhraseWindow - 1 do
    AContext.Languages[I - 1] := AContext.Languages[I];
  AContext.Languages[PhraseWindow - 1] := ALang;
end;

function PhraseScoreBias(const AContext: TPhraseContext; ALang: TLangKind): Integer;
var
  I, Hits: Integer;
begin
  // Two agreeing words add 2 points, three or more add 3.
  // The bonus stays under the balanced switch margin.
  Result := 0;
  if (ALang = lkUnknown) or (AContext.Count < 2) then
    Exit;
  Hits := 0;
  for I := 0 to AContext.Count - 1 do
    if AContext.Languages[I] = ALang then
      Inc(Hits);
  if Hits >= PhraseBiasCap then
    Result := PhraseBiasCap
  else if Hits >= 2 then
    Result := Hits;
end;

end.
