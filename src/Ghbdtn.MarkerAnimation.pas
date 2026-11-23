unit Ghbdtn.MarkerAnimation;

interface

uses
  Ghbdtn.Settings;

type
  { One frame of the dot's reaction to a layout change. Sizes are relative to
    the resting dot. }
  TDotFrame = record
    ScaleX: Double;
    ScaleY: Double;
    // 0 is a circle, 1 a square with sharp corners.
    Roundness: Double;
    // Rotation in radians.
    Angle: Double;
    // Progress of the outgoing ring, or a negative value when there is none.
    Wave: Double;
    // 0 is the previous layout's color, 1 the current one's.
    Mix: Double;
  end;

{ The dot as it rests: a circle of normal size in the current color. }
function RestingDotFrame: TDotFrame;

function MarkerAnimationMs(AStyle: TMarkerAnimation): Integer;

{ The frame at APhase (0 at the start, 1 at the end of the animation). A phase
  outside that range gives the resting frame. }
function ComputeDotFrame(AStyle: TMarkerAnimation;
  APhase: Double): TDotFrame;

implementation

uses
  System.Math;

const
  SwellPeak = 0.55;
  ShrinkDepth = 0.6;
  SquareRoundness = 0.9;
  // A square of the same half-width looks larger than a circle.
  SquareShrink = 0.12;
  FlipMinWidth = 0.04;
  WaveBulge = 0.15;
  FadeBulge = 0.12;

function Smooth(AValue: Double): Double;
begin
  if AValue <= 0 then
    Exit(0);
  if AValue >= 1 then
    Exit(1);
  Result := AValue * AValue * (3 - 2 * AValue);
end;

function RestingDotFrame: TDotFrame;
begin
  Result.ScaleX := 1;
  Result.ScaleY := 1;
  Result.Roundness := 0;
  Result.Angle := 0;
  Result.Wave := -1;
  Result.Mix := 1;
end;

function MarkerAnimationMs(AStyle: TMarkerAnimation): Integer;
begin
  case AStyle of
    maSquare: Result := 560;
    maWave: Result := 520;
    maFlip: Result := 420;
    maFade: Result := 400;
  else
    Result := 360;
  end;
end;

function StepMix(APhase: Double): Double;
begin
  if APhase < 0.5 then
    Result := 0
  else
    Result := 1;
end;

function ComputeDotFrame(AStyle: TMarkerAnimation;
  APhase: Double): TDotFrame;
var
  Scale, Morph: Double;
begin
  Result := RestingDotFrame;
  if (APhase < 0) or (APhase >= 1) then
    Exit;
  case AStyle of
    maSwell:
      begin
        Scale := 1 + SwellPeak * Sin(Pi * APhase);
        Result.ScaleX := Scale;
        Result.ScaleY := Scale;
        Result.Mix := StepMix(APhase);
      end;
    maShrink:
      begin
        Scale := 1 - ShrinkDepth * Sin(Pi * APhase);
        Result.ScaleX := Scale;
        Result.ScaleY := Scale;
        Result.Mix := StepMix(APhase);
      end;
    maSquare:
      begin
        // Into a square, a quarter turn, back into a circle; the color
        // changes while the square turns.
        if APhase < 0.25 then
          Morph := Smooth(APhase / 0.25)
        else if APhase < 0.75 then
          Morph := 1
        else
          Morph := 1 - Smooth((APhase - 0.75) / 0.25);
        Scale := 1 - SquareShrink * Morph;
        Result.ScaleX := Scale;
        Result.ScaleY := Scale;
        Result.Roundness := SquareRoundness * Morph;
        Result.Angle := (Pi / 2) * Smooth((APhase - 0.25) / 0.5);
        Result.Mix := Smooth((APhase - 0.4) / 0.2);
      end;
    maFlip:
      begin
        Result.ScaleX := Max(Abs(Cos(Pi * APhase)), FlipMinWidth);
        Result.Mix := StepMix(APhase);
      end;
    maWave:
      begin
        Scale := 1 + WaveBulge * Sin(Pi * APhase);
        Result.ScaleX := Scale;
        Result.ScaleY := Scale;
        Result.Wave := APhase;
      end;
    maFade:
      begin
        Scale := 1 + FadeBulge * Sin(Pi * APhase);
        Result.ScaleX := Scale;
        Result.ScaleY := Scale;
        Result.Mix := Smooth(APhase);
      end;
  end;
end;

end.
