program CarSimTest;

{ Console check of the car model: prints every preset's runs so the times can
  be compared with real cars. Build it as a Windows console app in RAD Studio
  (or with Free Pascal: fpc -Fu.. CarSimTest.dpr). }

{$APPTYPE CONSOLE}
{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
{$IFDEF FPC}
  SysUtils,
{$ELSE}
  System.SysUtils,
{$ENDIF}
  CarSim in '..\CarSim.pas';

const
  // rough real-world 1/4 mile times on a prepped strip, for comparison
  Expected: array[0..PresetCount - 1] of Double =
    (16.5, 14.0, 13.3, 12.6, 12.9, 12.3, 12.2, 10.0, 9.6, 6.0);

var
  I: Integer;
  Run: TCarRun;
  Surface: TSurface;
  Manual: Boolean;
  Line: string;
  Fails: Integer;
  ET: Double;
begin
  Fails := 0;
  Run := TCarRun.Create;
  try
    for I := 0 to PresetCount - 1 do
    begin
      Writeln(Presets[I].Name, '  (expected about ', FormatFloat('0.0', Expected[I]), ' s)');
      for Manual := False to True do
        for Surface := Low(TSurface) to High(TSurface) do
        begin
          Run.Start(Presets[I], Manual, Surface, rlQuarter, Presets[I].LaunchRpm);
          Run.Advance(60, True);
          if Manual then Line := '  manual ' else Line := '  auto   ';
          Line := Line + Format('%-14s 60ft %5.3f  1/8 %6.3f @ %5.1f km/h  1/4 %6.3f @ %5.1f km/h',
            [SurfaceNames[Surface], Run.SplitTime[sp60ft], Run.SplitTime[spEighth],
             Run.SplitSpeed[spEighth] * 3.6, Run.ET, Run.TrapSpeed * 3.6]);
          Writeln(Line);
          if (Surface = sfPrepped) and not Manual then
          begin
            ET := Run.ET;
            if Abs(ET - Expected[I]) > Expected[I] * 0.08 then
            begin
              Writeln('    ** more than 8% off the expected time');
              Inc(Fails);
            end;
          end;
        end;
      // launch checks with a manual: on idle (bog) and on the limiter (spin)
      Run.Start(Presets[I], True, sfPrepped, rlQuarter, 900);
      Run.Advance(60, True);
      Writeln(Format('  manual launch at idle:      1/4 %6.3f', [Run.ET]));
      Run.Start(Presets[I], True, sfPrepped, rlQuarter, Presets[I].RevLimit);
      Run.Advance(60, True);
      Writeln(Format('  manual launch on limiter:   1/4 %6.3f', [Run.ET]));
      Writeln;
    end;
  finally
    Run.Free;
  end;
  Writeln(Fails, ' preset(s) outside 8%');
  if Fails > 0 then
    ExitCode := 1;
end.
