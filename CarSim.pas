unit CarSim;

{ Drag Tree car model: works out a car's run down the track from its power,
  weight, gearing and tyres, the track surface and the driver's throttle.

  A "point mass" model stepped every millisecond:
    engine torque at the current rpm (curve built from peak power, softer
    low down, turbo lag below boost)
    -> clutch slip (manual) or torque converter (automatic) at launch
    -> gears and final drive, less drivetrain losses
    -> limited by tyre grip on the driven wheels (weight moves to the rear
       under acceleration), wheelspin when the tyres can't hold it
    -> less air drag and rolling resistance
    -> speed and distance.
  Gears change up automatically at the shift point.

  The elapsed time starts when the car leaves the stage beam (after the
  roll-out) and stops at the finish line, like a real time slip.

  No FireMonkey in here, so it can be tested with a console program
  (see Tests/CarSimTest.dpr). }

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

type
  TDrive = (drRWD, drFWD, drAWD);
  TTyres = (tyStreet, tyRadial, tySlick);
  TSurface = (sfPrepped, sfDry, sfWet);
  TRaceLength = (rlEighth, rl1000ft, rlQuarter);
  TSplit = (sp60ft, sp330ft, spEighth, sp1000ft, spQuarter);

  TCarSpec = record
    Name: string;
    PowerKW: Double;      // peak power
    PeakRpm: Double;      // rpm of peak power
    RevLimit: Double;
    ShiftRpm: Double;     // automatic up-shift point
    LaunchRpm: Double;    // manual gearbox: launch (two-step) rpm
    StallRpm: Double;     // automatic gearbox: torque converter stall speed
    Turbo: Boolean;       // less torque until boost builds
    WeightKg: Double;     // with driver
    Drive: TDrive;
    Tyres: TTyres;
    Gears: Integer;
    FirstRatio: Double;   // the other gears are spread between these two
    TopRatio: Double;
    FinalDrive: Double;
    TyreRadiusM: Double;
    CdA: Double;          // drag coefficient x frontal area, m2
    FrontFrac: Double;    // share of the weight on the front wheels at rest
    CgRatio: Double;      // centre of gravity height / wheelbase
  end;

  TRunState = (rsIdle, rsRunning, rsFinished);

  { One car's run. Call Start at the launch, then Advance with the time since
    the launch and whether the throttle is open, as often as you like. }
  TCarRun = class
  private
    FSpec: TCarSpec;
    FManual: Boolean;
    FSurface: TSurface;
    FFinishM: Double;
    FState: TRunState;
    FTime: Double;        // s since the launch
    FDist: Double;        // m since the launch
    FSpeed: Double;       // m/s
    FAccel: Double;       // m/s2, last step
    FGear: Integer;
    FEngineRpm: Double;
    FClutchSlip: Boolean; // manual: still slipping the clutch off the line
    FLaunchRpm: Double;
    FShiftLeft: Double;   // s left in the current gear change
    FSpinning: Boolean;
    FStartTime: Double;   // s since the launch when the car left the beam
    FSplitTime: array[TSplit] of Double; // elapsed time, 0 = not reached
    FSplitSpeed: array[TSplit] of Double;
    FMaxTime: Double;
    procedure Step(Dt: Double; Throttle: Boolean);
    function GetSplitTime(S: TSplit): Double;
    function GetSplitSpeed(S: TSplit): Double;
    function GetET: Double;
    function GetTrapSpeed: Double;
    function GetDistFromLine: Double;
  public
    procedure Start(const Spec: TCarSpec; Manual: Boolean; Surface: TSurface;
      Length: TRaceLength; LaunchRpm: Double);
    procedure Advance(ToTime: Double; Throttle: Boolean);
    procedure Abort;
    property State: TRunState read FState;
    property Time: Double read FTime;
    property Distance: Double read FDist;           // m since the launch
    property DistFromLine: Double read GetDistFromLine; // m past the start line
    property FinishM: Double read FFinishM;
    property Speed: Double read FSpeed;             // m/s
    property Gear: Integer read FGear;
    property EngineRpm: Double read FEngineRpm;
    property Spinning: Boolean read FSpinning;
    property SplitTime[S: TSplit]: Double read GetSplitTime;  // s, 0 if not reached
    property SplitSpeed[S: TSplit]: Double read GetSplitSpeed; // m/s
    property ET: Double read GetET;                 // s, 0 until finished
    property TrapSpeed: Double read GetTrapSpeed;   // m/s at the finish
    { time from the launch to crossing the finish line, s }
    property FinishTime: Double read FTime;
  end;

const
  RollOutM = 0.29;   // the car moves about 11.5 in before the stage beam clears
  SplitM: array[TSplit] of Double = (18.288, 100.584, 201.168, 304.8, 402.336);
  RaceSplit: array[TRaceLength] of TSplit = (spEighth, sp1000ft, spQuarter);
  RaceLengthNames: array[TRaceLength] of string = ('1/8 mile', '1000 ft', '1/4 mile');
  SplitNames: array[TSplit] of string = ('60 ft', '330 ft', '1/8 mile', '1000 ft', '1/4 mile');
  DriveNames: array[TDrive] of string = ('RWD', 'FWD', 'AWD');
  TyreNames: array[TTyres] of string = ('Street', 'Drag radial', 'Slick');
  SurfaceNames: array[TSurface] of string = ('Prepped strip', 'Dry street', 'Wet');
  MaxGears = 10;

  PresetCount = 10;
  Presets: array[0..PresetCount - 1] of TCarSpec = (
    (Name: 'Daily hatchback'; PowerKW: 90; PeakRpm: 6000; RevLimit: 6500;
     ShiftRpm: 6300; LaunchRpm: 3000; StallRpm: 2200; Turbo: False;
     WeightKg: 1150; Drive: drFWD; Tyres: tyStreet; Gears: 5;
     FirstRatio: 3.45; TopRatio: 0.80; FinalDrive: 4.10; TyreRadiusM: 0.30;
     CdA: 0.65; FrontFrac: 0.62; CgRatio: 0.22),
    (Name: 'Hot hatch'; PowerKW: 180; PeakRpm: 5800; RevLimit: 6800;
     ShiftRpm: 6500; LaunchRpm: 3500; StallRpm: 2600; Turbo: True;
     WeightKg: 1350; Drive: drFWD; Tyres: tyStreet; Gears: 6;
     FirstRatio: 3.50; TopRatio: 0.75; FinalDrive: 3.90; TyreRadiusM: 0.32;
     CdA: 0.68; FrontFrac: 0.62; CgRatio: 0.21),
    (Name: 'Turbo AWD sedan'; PowerKW: 220; PeakRpm: 6000; RevLimit: 7000;
     ShiftRpm: 6800; LaunchRpm: 4500; StallRpm: 3000; Turbo: True;
     WeightKg: 1500; Drive: drAWD; Tyres: tyStreet; Gears: 6;
     FirstRatio: 3.60; TopRatio: 0.80; FinalDrive: 3.90; TyreRadiusM: 0.32;
     CdA: 0.70; FrontFrac: 0.60; CgRatio: 0.21),
    (Name: 'Twin turbo AWD sedan'; PowerKW: 330; PeakRpm: 6000; RevLimit: 6800;
     ShiftRpm: 6600; LaunchRpm: 4000; StallRpm: 3000; Turbo: True;
     WeightKg: 1900; Drive: drAWD; Tyres: tyStreet; Gears: 8;
     FirstRatio: 4.70; TopRatio: 0.67; FinalDrive: 3.15; TyreRadiusM: 0.34;
     CdA: 0.72; FrontFrac: 0.55; CgRatio: 0.20),
    (Name: 'V8 sedan'; PowerKW: 300; PeakRpm: 6000; RevLimit: 6500;
     ShiftRpm: 6300; LaunchRpm: 3500; StallRpm: 2500; Turbo: False;
     WeightKg: 1800; Drive: drRWD; Tyres: tyStreet; Gears: 6;
     FirstRatio: 4.03; TopRatio: 0.67; FinalDrive: 3.27; TyreRadiusM: 0.34;
     CdA: 0.75; FrontFrac: 0.54; CgRatio: 0.20),
    (Name: 'Modern muscle car'; PowerKW: 340; PeakRpm: 7000; RevLimit: 7500;
     ShiftRpm: 7300; LaunchRpm: 4000; StallRpm: 2600; Turbo: False;
     WeightKg: 1750; Drive: drRWD; Tyres: tyStreet; Gears: 6;
     FirstRatio: 3.66; TopRatio: 0.65; FinalDrive: 3.73; TyreRadiusM: 0.35;
     CdA: 0.78; FrontFrac: 0.53; CgRatio: 0.19),
    (Name: 'Supercharged V8'; PowerKW: 485; PeakRpm: 6000; RevLimit: 6500;
     ShiftRpm: 6300; LaunchRpm: 3500; StallRpm: 2800; Turbo: False;
     WeightKg: 1900; Drive: drRWD; Tyres: tyStreet; Gears: 8;
     FirstRatio: 4.70; TopRatio: 0.67; FinalDrive: 3.15; TyreRadiusM: 0.35;
     CdA: 0.80; FrontFrac: 0.54; CgRatio: 0.19),
    (Name: 'Superbike'; PowerKW: 150; PeakRpm: 13000; RevLimit: 14000;
     ShiftRpm: 13800; LaunchRpm: 11000; StallRpm: 6000; Turbo: False;
     WeightKg: 280; Drive: drRWD; Tyres: tyStreet; Gears: 6;
     FirstRatio: 2.60; TopRatio: 1.00; FinalDrive: 4.30; TyreRadiusM: 0.31;
     CdA: 0.35; FrontFrac: 0.50; CgRatio: 0.45),
    (Name: 'Street/strip turbo'; PowerKW: 600; PeakRpm: 7000; RevLimit: 7500;
     ShiftRpm: 7300; LaunchRpm: 5000; StallRpm: 4500; Turbo: True;
     WeightKg: 1500; Drive: drRWD; Tyres: tyRadial; Gears: 3;
     FirstRatio: 2.48; TopRatio: 1.00; FinalDrive: 3.70; TyreRadiusM: 0.36;
     CdA: 0.75; FrontFrac: 0.53; CgRatio: 0.18),
    (Name: 'Pro-mod style'; PowerKW: 2400; PeakRpm: 8000; RevLimit: 8500;
     ShiftRpm: 8300; LaunchRpm: 6000; StallRpm: 6000; Turbo: False;
     WeightKg: 1200; Drive: drRWD; Tyres: tySlick; Gears: 5;
     FirstRatio: 2.00; TopRatio: 1.00; FinalDrive: 3.00; TyreRadiusM: 0.45;
     CdA: 0.80; FrontFrac: 0.45; CgRatio: 0.12)
  );

function GearRatio(const Spec: TCarSpec; Gear: Integer): Double;
function EngineTorque(const Spec: TCarSpec; Rpm: Double): Double;
function SpecsEqual(const A, B: TCarSpec): Boolean;
{ a full-throttle run with a good launch, for the estimate on the Car screen }
procedure EstimateRun(const Spec: TCarSpec; Manual: Boolean; Surface: TSurface;
  Length: TRaceLength; out ET, TrapSpeed: Double);

implementation

uses
{$IFDEF FPC}
  SysUtils, Math;
{$ELSE}
  System.SysUtils, System.Math;
{$ENDIF}

const
  G = 9.81;
  AirDensity = 1.2;
  RollingRes = 0.015;
  IdleRpm = 900.0;
  StepS = 0.001;            // 1 ms steps
  ManualShiftS = 0.15;      // no drive while the clutch is in
  AutoShiftS = 0.20;        // automatic: drive drops, then comes back
  AutoShiftDrive = 0.4;
  KineticGrip = 0.88;       // a spinning tyre grips this much less
  TurboBoostFrac = 0.50;    // turbo: full boost from half the peak-power rpm
  TurboLagTorque = 0.55;    // torque before boost

  // tyre grip on a prepped drag strip
  TyreGrip: array[TTyres] of Double = (1.50, 2.20, 3.60);
  // how much of that each surface gives, by tyre (slicks are hopeless wet)
  SurfaceGrip: array[TSurface, TTyres] of Double = (
    (1.00, 1.00, 1.00),     // prepped strip
    (0.85, 0.70, 0.55),     // dry street: no traction compound
    (0.55, 0.35, 0.18));    // wet

function GearRatio(const Spec: TCarSpec; Gear: Integer): Double;
begin
  // gears spread evenly (geometrically) from first to top
  if Spec.Gears <= 1 then
    Result := Spec.FirstRatio
  else
    Result := Spec.FirstRatio * Power(Spec.TopRatio / Spec.FirstRatio,
      (EnsureRange(Gear, 1, Spec.Gears) - 1) / (Spec.Gears - 1));
end;

function EngineTorque(const Spec: TCarSpec; Rpm: Double): Double;
var
  X, PeakW, Omega, LowRpm: Double;
begin
  // power curve P = Pmax (x + x^2 - x^3), x = rpm / peak-power rpm: peaks
  // where it should and gives peak torque at about half the peak rpm
  Result := 0;
  if Rpm <= 0 then
    Exit;
  X := Rpm / Spec.PeakRpm;
  PeakW := Spec.PowerKW * 1000;
  Omega := Spec.PeakRpm * 2 * Pi / 60;
  Result := PeakW / Omega * (1 + X - X * X);
  if Result < 0 then
    Result := 0;
  // weak just off idle, so launching on no revs bogs
  LowRpm := EnsureRange((Rpm - 600) / 1400, 0.15, 1.0);
  Result := Result * LowRpm;
  if Spec.Turbo then
    Result := Result * (TurboLagTorque + (1 - TurboLagTorque) *
      Sqr(EnsureRange(X / TurboBoostFrac, 0.0, 1.0)));
end;

function SpecsEqual(const A, B: TCarSpec): Boolean;
begin
  Result := SameValue(A.PowerKW, B.PowerKW) and SameValue(A.PeakRpm, B.PeakRpm)
    and SameValue(A.RevLimit, B.RevLimit) and SameValue(A.ShiftRpm, B.ShiftRpm)
    and SameValue(A.LaunchRpm, B.LaunchRpm) and SameValue(A.StallRpm, B.StallRpm)
    and (A.Turbo = B.Turbo) and SameValue(A.WeightKg, B.WeightKg)
    and (A.Drive = B.Drive) and (A.Tyres = B.Tyres) and (A.Gears = B.Gears)
    and SameValue(A.FirstRatio, B.FirstRatio) and SameValue(A.TopRatio, B.TopRatio)
    and SameValue(A.FinalDrive, B.FinalDrive);
end;

procedure EstimateRun(const Spec: TCarSpec; Manual: Boolean; Surface: TSurface;
  Length: TRaceLength; out ET, TrapSpeed: Double);
var
  Run: TCarRun;
begin
  Run := TCarRun.Create;
  try
    Run.Start(Spec, Manual, Surface, Length, Spec.LaunchRpm);
    Run.Advance(60, True);
    ET := Run.ET;
    TrapSpeed := Run.TrapSpeed;
  finally
    Run.Free;
  end;
end;

{ TCarRun }

procedure TCarRun.Start(const Spec: TCarSpec; Manual: Boolean; Surface: TSurface;
  Length: TRaceLength; LaunchRpm: Double);
var
  S: TSplit;
begin
  FSpec := Spec;
  FSpec.Gears := EnsureRange(FSpec.Gears, 1, MaxGears);
  FManual := Manual;
  FSurface := Surface;
  FFinishM := SplitM[RaceSplit[Length]];
  FState := rsRunning;
  FTime := 0;
  FDist := 0;
  FSpeed := 0;
  FAccel := 0;
  FGear := 1;
  FShiftLeft := 0;
  FSpinning := False;
  FStartTime := -1;
  FLaunchRpm := EnsureRange(LaunchRpm, IdleRpm, FSpec.RevLimit - 100);
  FClutchSlip := Manual;
  if Manual then
    FEngineRpm := FLaunchRpm
  else
    FEngineRpm := FSpec.StallRpm;
  for S := Low(TSplit) to High(TSplit) do
  begin
    FSplitTime[S] := 0;
    FSplitSpeed[S] := 0;
  end;
  FMaxTime := 30; // given up: the throttle was never opened
end;

procedure TCarRun.Abort;
begin
  FState := rsIdle;
end;

procedure TCarRun.Advance(ToTime: Double; Throttle: Boolean);
begin
  while (FState = rsRunning) and (FTime + StepS <= ToTime) do
    Step(StepS, Throttle);
end;

procedure TCarRun.Step(Dt: Double; Throttle: Boolean);
var
  Ratio, WheelRpm, Rpm, Torque, Drive, Normal, Grip, MaxA, Drag, Mass,
    MassEff, NetF, Eff, OldDist, Frac, SplitET: Double;
  S: TSplit;
begin
  Ratio := GearRatio(FSpec, FGear) * FSpec.FinalDrive;
  WheelRpm := FSpeed / FSpec.TyreRadiusM * 60 / (2 * Pi) * Ratio; // engine side
  Mass := FSpec.WeightKg;
  if FSpec.Drive = drAWD then
    Eff := 0.85
  else
    Eff := 0.88;

  // ----- engine and what reaches the gearbox -----
  Torque := 0;
  if FManual then
  begin
    if FClutchSlip and (WheelRpm >= FLaunchRpm) then
      FClutchSlip := False;
    if FClutchSlip then
      Rpm := FLaunchRpm          // the driver holds the launch revs
    else
      Rpm := WheelRpm;
    if Throttle and (FShiftLeft <= 0) and (Rpm < FSpec.RevLimit) then
      Torque := EngineTorque(FSpec, Rpm);
  end
  else
  begin
    // torque converter: the engine sits at stall until the car catches up,
    // with up to twice the torque at a standstill
    if Throttle then
      Rpm := Max(WheelRpm * 1.04, FSpec.StallRpm)
    else
      Rpm := Max(WheelRpm * 1.04, IdleRpm);
    if Throttle and (Rpm < FSpec.RevLimit) then
    begin
      Torque := EngineTorque(FSpec, Rpm) *
        Max(1.0, 2.0 - (WheelRpm / Rpm) / 0.85);
      if FShiftLeft > 0 then
        Torque := Torque * AutoShiftDrive;
    end;
  end;
  FEngineRpm := Rpm;

  // ----- force at the tyres, limited by grip -----
  Drive := Torque * Ratio * Eff / FSpec.TyreRadiusM;
  case FSpec.Drive of
    drRWD: Normal := Mass * G * (1 - FSpec.FrontFrac) + Mass * FAccel * FSpec.CgRatio;
    drFWD: Normal := Mass * G * FSpec.FrontFrac - Mass * FAccel * FSpec.CgRatio;
  else
    Normal := Mass * G;
  end;
  if Normal < 0 then
    Normal := 0;
  Grip := TyreGrip[FSpec.Tyres] * SurfaceGrip[FSurface, FSpec.Tyres] * Normal;
  if FSpinning then
  begin
    if Drive < Grip * 0.95 then
      FSpinning := False
    else
      Drive := Grip * KineticGrip;
  end
  else if Drive > Grip then
  begin
    FSpinning := True;
    Drive := Grip * KineticGrip;
  end;

  // throttle shut: a little engine braking
  if not Throttle and (FSpeed > 0.1) then
    Drive := -0.02 * Mass * G;

  // ----- resistance, mass and motion -----
  Drag := 0.5 * AirDensity * FSpec.CdA * FSpeed * FSpeed;
  if FSpeed > 0.01 then
    Drag := Drag + RollingRes * Mass * G;
  NetF := Drive - Drag;
  // spinning wheels, shafts and the engine add to the mass, most in low gears
  MassEff := Mass * (1.03 + 0.0015 * Ratio * Ratio);
  FAccel := NetF / MassEff;
  // the front lifts (wheelie) once the front wheels carry no weight
  MaxA := G * FSpec.FrontFrac / FSpec.CgRatio;
  if FAccel > MaxA then
    FAccel := MaxA;
  if (FSpeed <= 0) and (FAccel < 0) then
    FAccel := 0;

  OldDist := FDist;
  FSpeed := Max(0.0, FSpeed + FAccel * Dt);
  FDist := FDist + FSpeed * Dt;
  FTime := FTime + Dt;

  // ----- gears -----
  if FShiftLeft > 0 then
  begin
    FShiftLeft := FShiftLeft - Dt;
    if FShiftLeft <= 0 then
      Inc(FGear);
  end
  else if (FGear < FSpec.Gears) and not FClutchSlip
    and (FEngineRpm >= FSpec.ShiftRpm) and (WheelRpm >= FSpec.ShiftRpm * 0.95) then
  begin
    if FManual then
      FShiftLeft := ManualShiftS
    else
      FShiftLeft := AutoShiftS;
  end;

  // ----- timing: start at the beam, splits from the start line -----
  if (FStartTime < 0) and (FDist >= RollOutM) then
    FStartTime := FTime - (FDist - RollOutM) / Max(FSpeed, 0.001);
  if FStartTime >= 0 then
    for S := Low(TSplit) to High(TSplit) do
      if (FSplitTime[S] = 0) and (FDist - RollOutM >= SplitM[S]) then
      begin
        // between steps: share out the step
        Frac := (SplitM[S] + RollOutM - OldDist) / Max(FDist - OldDist, 1e-9);
        SplitET := FTime - Dt + Frac * Dt - FStartTime;
        FSplitTime[S] := SplitET;
        FSplitSpeed[S] := FSpeed;
        if SameValue(SplitM[S], FFinishM) then
        begin
          FTime := FTime - Dt + Frac * Dt;
          FState := rsFinished;
        end;
      end;

  if (FState = rsRunning) and (FTime > FMaxTime) then
    FState := rsIdle; // never got there
end;

function TCarRun.GetSplitTime(S: TSplit): Double;
begin
  Result := FSplitTime[S];
end;

function TCarRun.GetSplitSpeed(S: TSplit): Double;
begin
  Result := FSplitSpeed[S];
end;

function TCarRun.GetET: Double;
var
  S: TSplit;
begin
  Result := 0;
  if FState <> rsFinished then
    Exit;
  for S := Low(TSplit) to High(TSplit) do
    if SameValue(SplitM[S], FFinishM) then
      Result := FSplitTime[S];
end;

function TCarRun.GetTrapSpeed: Double;
var
  S: TSplit;
begin
  Result := 0;
  for S := Low(TSplit) to High(TSplit) do
    if SameValue(SplitM[S], FFinishM) then
      Result := FSplitSpeed[S];
end;

function TCarRun.GetDistFromLine: Double;
begin
  Result := FDist - RollOutM;
end;

end.
