unit Ghbdtn.Buffer;

interface

uses
  System.SysUtils,
  Ghbdtn.Layout;

type
  TInputBuffer = class
  private
    FBufferText: string;
    FInputLang: TLangKind;
    function GetBufferLength: Integer;
  public
    constructor Create;
    procedure Clear;
    procedure AddChar(AChar: Char; ALang: TLangKind);
    procedure RemoveLastChar;

    property BufferText: string read FBufferText;
    property InputLang: TLangKind read FInputLang write FInputLang;
    function IsEmpty: Boolean;
    property BufferLength: Integer read GetBufferLength;
  end;

implementation

constructor TInputBuffer.Create;
begin
  inherited Create;
  Clear;
end;

procedure TInputBuffer.Clear;
begin
  FBufferText := '';
  FInputLang := lkUnknown;
end;

procedure TInputBuffer.AddChar(AChar: Char; ALang: TLangKind);
begin
  if FBufferText = '' then
    FInputLang := ALang;

  FBufferText := FBufferText + AChar;
end;

procedure TInputBuffer.RemoveLastChar;
var
  L: Integer;
begin
  L := System.Length(FBufferText);
  if L > 0 then
    Delete(FBufferText, L, 1);
  if FBufferText = '' then
    FInputLang := lkUnknown;
end;

function TInputBuffer.IsEmpty: Boolean;
begin
  Result := FBufferText = '';
end;

function TInputBuffer.GetBufferLength: Integer;
begin
  Result := System.Length(FBufferText);
end;

end.
