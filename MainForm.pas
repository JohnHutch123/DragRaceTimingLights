unit MainForm;

{ Pro tree reaction time trainer.

  Sequence for one run (all times measured with TStopwatch):
    START  -> pre-stage bulbs on
           -> stage bulbs on after a short pause
           -> random wait (0.8 to 3.0 s)
           -> all three ambers on together (Pro tree)
           -> 0.400 s later ambers off, green on

  Reaction time = launch tap time - (amber on time + 0.400 s).
  0.000 is a perfect light; anything below zero is a red light. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math,
  System.Diagnostics, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Objects, FMX.StdCtrls,
  FMX.Layouts, FMX.Controls.Presentation;

const
  ProTreeDelayMs = 400.0;   // ambers to green on a Pro tree
  PreStageToStageMinMs = 600;
  PreStageToStageRandMs = 400;
  StageToAmberMinMs = 800;  // random auto-start delay after staging
  StageToAmberRandMs = 2200;
  HistoryLines = 20;

type
  TTreePhase = (tpIdle, tpPreStaged, tpStaged, tpAmbers, tpGreen, tpFinished);

  TRunResult = record
    ReactionMs: Double;
    Foul: Boolean;
  end;

  TfrmMain = class(TForm)
    layTop: TLayout;
    lblReaction: TLabel;
    lblVerdict: TLabel;
    lblStats: TLabel;
    layMiddle: TLayout;
    pbTree: TPaintBox;
    rectHistory: TRectangle;
    lblHistoryTitle: TLabel;
    lblHistory: TLabel;
    rectLaunch: TRectangle;
    lblLaunch: TLabel;
    layButtons: TLayout;
    btnStart: TButton;
    btnStop: TButton;
    btnReset: TButton;
    btnClear: TButton;
    tmrTree: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar;
      Shift: TShiftState);
    procedure pbTreePaint(Sender: TObject; Canvas: TCanvas);
    procedure tmrTreeTimer(Sender: TObject);
    procedure rectLaunchMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnResetClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure layButtonsResize(Sender: TObject);
  private
    FWatch: TStopwatch;
    FPhase: TTreePhase;
    FStageDueMs: Double;
    FAmberDueMs: Double;
    FAmberOnMs: Double;
    FPreStageLit: Boolean;
    FStageLit: Boolean;
    FAmberLit: Boolean;
    FGreenLit: Boolean;
    FRedLit: Boolean;
    FResults: TList<TRunResult>;
    function NowMs: Double;
    function GreenDueMs: Double;
    procedure StyleLabel(L: TLabel; Size: Single; Color: TAlphaColor;
      Bold: Boolean; Align: TTextAlign);
    procedure ApplyLook;
    procedure LightsOff;
    procedure ResetTree;
    procedure StartRun;
    procedure StopRun;
    procedure Launch(TapMs: Double);
    procedure ShowResult(const R: TRunResult);
    procedure UpdateLaunchText;
    procedure UpdateStats;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

const
  clrBackground = TAlphaColor($FF121212);
  clrPanel      = TAlphaColor($FF1E1E1E);
  clrHousing    = TAlphaColor($FF262626);
  clrRim        = TAlphaColor($FF050505);
  clrStage      = TAlphaColor($FFFFF4C8);
  clrAmber      = TAlphaColor($FFFFB000);
  clrGreen      = TAlphaColor($FF19FF4A);
  clrRed        = TAlphaColor($FFFF2424);
  clrText       = TAlphaColor($FFF0F0F0);
  clrSubtle     = TAlphaColor($FF9A9A9A);

function FormatSecs(Ms: Double): string;
begin
  Result := Format('%.3f', [Ms / 1000], TFormatSettings.Invariant);
end;

function DimColor(C: TAlphaColor; F: Single): TAlphaColor;
var
  R: TAlphaColorRec;
begin
  R := TAlphaColorRec(C);
  R.R := Round(R.R * F);
  R.G := Round(R.G * F);
  R.B := Round(R.B * F);
  Result := R.Color;
end;

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Randomize;
  FResults := TList<TRunResult>.Create;
  FWatch := TStopwatch.StartNew;
  ApplyLook;
  ResetTree;
  UpdateStats;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FResults.Free;
end;

function TfrmMain.NowMs: Double;
begin
  Result := FWatch.Elapsed.TotalMilliseconds;
end;

function TfrmMain.GreenDueMs: Double;
begin
  // Before the ambers have actually lit, judge against the scheduled time
  if FPhase in [tpPreStaged, tpStaged] then
    Result := FAmberDueMs + ProTreeDelayMs
  else
    Result := FAmberOnMs + ProTreeDelayMs;
end;

procedure TfrmMain.StyleLabel(L: TLabel; Size: Single; Color: TAlphaColor;
  Bold: Boolean; Align: TTextAlign);
begin
  L.StyledSettings := L.StyledSettings - [TStyledSetting.Size,
    TStyledSetting.FontColor, TStyledSetting.Style];
  L.TextSettings.Font.Size := Size;
  L.TextSettings.FontColor := Color;
  if Bold then
    L.TextSettings.Font.Style := [TFontStyle.fsBold]
  else
    L.TextSettings.Font.Style := [];
  L.TextSettings.HorzAlign := Align;
  L.HitTest := False;
end;

procedure TfrmMain.ApplyLook;
begin
  Fill.Kind := TBrushKind.Solid;
  Fill.Color := clrBackground;
{$IFDEF IOS}
  // Keep clear of the notch and the home indicator
  Padding.Top := 44;
  Padding.Bottom := 20;
{$ENDIF}

  StyleLabel(lblReaction, 52, clrText, True, TTextAlign.Center);
  StyleLabel(lblVerdict, 20, clrSubtle, True, TTextAlign.Center);
  StyleLabel(lblStats, 14, clrSubtle, False, TTextAlign.Center);
  StyleLabel(lblHistoryTitle, 14, clrSubtle, True, TTextAlign.Center);
  StyleLabel(lblHistory, 14, clrText, False, TTextAlign.Leading);
  lblHistory.TextSettings.VertAlign := TTextAlign.Leading;
  lblHistory.WordWrap := True;
  StyleLabel(lblLaunch, 24, clrText, True, TTextAlign.Center);

  rectHistory.Fill.Kind := TBrushKind.Solid;
  rectHistory.Fill.Color := clrPanel;
  rectHistory.Stroke.Kind := TBrushKind.None;

  rectLaunch.Fill.Kind := TBrushKind.Solid;
  rectLaunch.Fill.Color := TAlphaColor($FF2C2C2C);
  rectLaunch.Stroke.Kind := TBrushKind.Solid;
  rectLaunch.Stroke.Color := TAlphaColor($FF4A4A4A);
  rectLaunch.Stroke.Thickness := 2;

  // Buttons must not take focus, otherwise the space bar "clicks" them
  btnStart.CanFocus := False;
  btnStop.CanFocus := False;
  btnReset.CanFocus := False;
  btnClear.CanFocus := False;
end;

procedure TfrmMain.layButtonsResize(Sender: TObject);
var
  W: Single;
begin
  W := layButtons.Width / 4 - btnStart.Margins.Left - btnStart.Margins.Right;
  btnStart.Width := W;
  btnStop.Width := W;
  btnReset.Width := W;
  btnClear.Width := W;
end;

procedure TfrmMain.LightsOff;
begin
  FPreStageLit := False;
  FStageLit := False;
  FAmberLit := False;
  FGreenLit := False;
  FRedLit := False;
end;

procedure TfrmMain.ResetTree;
begin
  tmrTree.Enabled := False;
  FPhase := tpIdle;
  LightsOff;
  lblReaction.Text := '-.---';
  lblReaction.TextSettings.FontColor := clrText;
  lblVerdict.Text := 'Press START to stage';
  lblVerdict.TextSettings.FontColor := clrSubtle;
  UpdateLaunchText;
  pbTree.Repaint;
end;

procedure TfrmMain.StartRun;
begin
  ResetTree;
  FStageDueMs := NowMs + PreStageToStageMinMs + Random(PreStageToStageRandMs);
  FAmberDueMs := FStageDueMs + StageToAmberMinMs + Random(StageToAmberRandMs);
  FAmberOnMs := 0;
  FPreStageLit := True;
  FPhase := tpPreStaged;
  lblVerdict.Text := 'Staging...';
  UpdateLaunchText;
  tmrTree.Enabled := True;
  pbTree.Repaint;
end;

procedure TfrmMain.StopRun;
begin
  tmrTree.Enabled := False;
  FPhase := tpIdle;
  LightsOff;
  lblVerdict.Text := 'Stopped';
  lblVerdict.TextSettings.FontColor := clrSubtle;
  UpdateLaunchText;
  pbTree.Repaint;
end;

procedure TfrmMain.tmrTreeTimer(Sender: TObject);
var
  T: Double;
begin
  T := NowMs;
  case FPhase of
    tpPreStaged:
      if T >= FStageDueMs then
      begin
        FStageLit := True;
        FPhase := tpStaged;
        lblVerdict.Text := 'Staged';
        pbTree.Repaint;
      end;
    tpStaged:
      if T >= FAmberDueMs then
      begin
        FAmberLit := True;
        FAmberOnMs := NowMs;
        FPhase := tpAmbers;
        pbTree.Repaint;
      end;
    tpAmbers:
      if T >= FAmberOnMs + ProTreeDelayMs then
      begin
        FAmberLit := False;
        FGreenLit := True;
        FPhase := tpGreen;
        tmrTree.Enabled := False;
        pbTree.Repaint;
      end;
  else
    tmrTree.Enabled := False;
  end;
end;

procedure TfrmMain.rectLaunchMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  Launch(NowMs);
end;

procedure TfrmMain.FormKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: WideChar; Shift: TShiftState);
begin
  // Desktop testing: space launches, Enter starts a run
  if KeyChar = ' ' then
  begin
    Launch(NowMs);
    KeyChar := #0;
  end
  else if Key = vkReturn then
  begin
    StartRun;
    Key := 0;
  end;
end;

procedure TfrmMain.Launch(TapMs: Double);
var
  R: TRunResult;
begin
  if not (FPhase in [tpPreStaged, tpStaged, tpAmbers, tpGreen]) then
    Exit;

  tmrTree.Enabled := False;
  R.ReactionMs := TapMs - GreenDueMs;
  R.Foul := R.ReactionMs < 0;

  FAmberLit := False;
  if R.Foul then
  begin
    FGreenLit := False;
    FRedLit := True;
  end
  else
    FGreenLit := True;

  FPhase := tpFinished;
  FResults.Add(R);
  ShowResult(R);
  UpdateStats;
  UpdateLaunchText;
  pbTree.Repaint;
end;

procedure TfrmMain.ShowResult(const R: TRunResult);
var
  Verdict: string;
  Color: TAlphaColor;
begin
  lblReaction.Text := FormatSecs(R.ReactionMs);
  if R.Foul then
  begin
    Verdict := 'RED LIGHT';
    Color := clrRed;
  end
  else
  begin
    Color := clrGreen;
    if R.ReactionMs < 10 then
      Verdict := 'PERFECT LIGHT!'
    else if R.ReactionMs < 50 then
      Verdict := 'Great light'
    else if R.ReactionMs < 100 then
      Verdict := 'Good light'
    else if R.ReactionMs < 200 then
    begin
      Verdict := 'A bit late';
      Color := clrAmber;
    end
    else
    begin
      Verdict := 'Asleep on the tree';
      Color := clrAmber;
    end;
  end;
  lblReaction.TextSettings.FontColor := Color;
  lblVerdict.Text := Verdict;
  lblVerdict.TextSettings.FontColor := Color;
end;

procedure TfrmMain.UpdateLaunchText;
begin
  case FPhase of
    tpIdle:
      lblLaunch.Text := 'Press START';
    tpFinished:
      lblLaunch.Text := 'START for another run';
  else
    lblLaunch.Text := 'TAP TO LAUNCH';
  end;
end;

procedure TfrmMain.UpdateStats;
var
  I, Good, Fouls: Integer;
  Sum, Best: Double;
  R: TRunResult;
  Lines: TStringBuilder;
begin
  Good := 0;
  Fouls := 0;
  Sum := 0;
  Best := MaxDouble;
  for R in FResults do
    if R.Foul then
      Inc(Fouls)
    else
    begin
      Inc(Good);
      Sum := Sum + R.ReactionMs;
      Best := Min(Best, R.ReactionMs);
    end;

  if Good > 0 then
    lblStats.Text := Format('Runs %d   Best %s   Avg %s   Red %d',
      [FResults.Count, FormatSecs(Best), FormatSecs(Sum / Good), Fouls])
  else
    lblStats.Text := Format('Runs %d   Best -.---   Avg -.---   Red %d',
      [FResults.Count, Fouls]);

  Lines := TStringBuilder.Create;
  try
    I := FResults.Count - 1;
    while (I >= 0) and (I >= FResults.Count - HistoryLines) do
    begin
      R := FResults[I];
      Lines.Append(Format('#%d  %s', [I + 1, FormatSecs(R.ReactionMs)]));
      if R.Foul then
        Lines.Append('  R');
      Lines.Append(sLineBreak);
      Dec(I);
    end;
    lblHistory.Text := Lines.ToString;
  finally
    Lines.Free;
  end;
end;

procedure TfrmMain.btnStartClick(Sender: TObject);
begin
  StartRun;
end;

procedure TfrmMain.btnStopClick(Sender: TObject);
begin
  StopRun;
end;

procedure TfrmMain.btnResetClick(Sender: TObject);
begin
  ResetTree;
end;

procedure TfrmMain.btnClearClick(Sender: TObject);
begin
  FResults.Clear;
  ResetTree;
  UpdateStats;
end;

procedure TfrmMain.pbTreePaint(Sender: TObject; Canvas: TCanvas);
const
  Rows = 7; // pre-stage, stage, amber x3, green, red
var
  W, H, RowH, R, SmallR: Single;
  LaneX: array[0..1] of Single;
  Lane: Integer;

  function RowY(Row: Integer): Single;
  begin
    Result := 12 + RowH * (Row + 0.5);
  end;

  procedure Bulb(CX, CY, Radius: Single; Color: TAlphaColor; Lit: Boolean);
  begin
    Canvas.Fill.Kind := TBrushKind.Solid;
    if Lit then
    begin
      // soft glow, then the lens, then a highlight
      Canvas.Fill.Color := Color;
      Canvas.FillEllipse(RectF(CX - Radius * 1.6, CY - Radius * 1.6,
        CX + Radius * 1.6, CY + Radius * 1.6), 0.12);
      Canvas.FillEllipse(RectF(CX - Radius * 1.25, CY - Radius * 1.25,
        CX + Radius * 1.25, CY + Radius * 1.25), 0.25);
      Canvas.FillEllipse(RectF(CX - Radius, CY - Radius,
        CX + Radius, CY + Radius), 1);
      Canvas.Fill.Color := TAlphaColors.White;
      Canvas.FillEllipse(RectF(CX - Radius * 0.55, CY - Radius * 0.6,
        CX - Radius * 0.05, CY - Radius * 0.15), 0.55);
    end
    else
    begin
      Canvas.Fill.Color := DimColor(Color, 0.16);
      Canvas.FillEllipse(RectF(CX - Radius, CY - Radius,
        CX + Radius, CY + Radius), 1);
    end;
    Canvas.Stroke.Kind := TBrushKind.Solid;
    Canvas.Stroke.Color := clrRim;
    Canvas.StrokeThickness := Max(2, Radius * 0.12);
    Canvas.DrawEllipse(RectF(CX - Radius, CY - Radius,
      CX + Radius, CY + Radius), 1);
  end;

begin
  W := pbTree.Width;
  H := pbTree.Height;
  if (W < 20) or (H < 20) then
    Exit;

  RowH := (H - 24) / Rows;
  LaneX[0] := W * 0.30;
  LaneX[1] := W * 0.70;
  R := Min(W * 0.14, RowH * 0.42);
  SmallR := R * 0.42;

  // Pole and housings
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := clrHousing;
  Canvas.FillRect(RectF(W * 0.5 - 6, 0, W * 0.5 + 6, H), 0, 0, AllCorners, 1);
  for Lane := 0 to 1 do
    Canvas.FillRect(RectF(LaneX[Lane] - R * 1.6, 4, LaneX[Lane] + R * 1.6, H - 4),
      R * 0.6, R * 0.6, AllCorners, 1);

  for Lane := 0 to 1 do
  begin
    // Pre-stage and stage are pairs of small bulbs
    Bulb(LaneX[Lane] - SmallR * 1.3, RowY(0), SmallR, clrStage, FPreStageLit);
    Bulb(LaneX[Lane] + SmallR * 1.3, RowY(0), SmallR, clrStage, FPreStageLit);
    Bulb(LaneX[Lane] - SmallR * 1.3, RowY(1), SmallR, clrStage, FStageLit);
    Bulb(LaneX[Lane] + SmallR * 1.3, RowY(1), SmallR, clrStage, FStageLit);

    Bulb(LaneX[Lane], RowY(2), R, clrAmber, FAmberLit);
    Bulb(LaneX[Lane], RowY(3), R, clrAmber, FAmberLit);
    Bulb(LaneX[Lane], RowY(4), R, clrAmber, FAmberLit);

    // Left lane is you; the right lane is a mirror with no opponent
    if Lane = 0 then
    begin
      Bulb(LaneX[Lane], RowY(5), R, clrGreen, FGreenLit);
      Bulb(LaneX[Lane], RowY(6), R, clrRed, FRedLit);
    end
    else
    begin
      Bulb(LaneX[Lane], RowY(5), R, clrGreen,
        FGreenLit or (FRedLit and (FPhase = tpFinished)));
      Bulb(LaneX[Lane], RowY(6), R, clrRed, False);
    end;
  end;
end;

end.
