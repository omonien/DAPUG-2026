program ImageUpscaleService.Tests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF }
  IUS.Tests.Prompt in 'IUS.Tests.Prompt.pas',
  IUS.Tests.Validation in 'IUS.Tests.Validation.pas',
  IUS.Upscaler.Fake in '..\src\IUS.Upscaler.Fake.pas',
  IUS.Tests.Upscaler.Fake in 'IUS.Tests.Upscaler.Fake.pas',
  IUS.Storage in '..\src\IUS.Storage.pas',
  IUS.Tests.Storage in 'IUS.Tests.Storage.pas',
  IUS.JobQueue in '..\src\IUS.JobQueue.pas',
  IUS.Tests.JobQueue in 'IUS.Tests.JobQueue.pas',
  IUS.Config in '..\src\IUS.Config.pas',
  IUS.Tests.Config in 'IUS.Tests.Config.pas',
  IUS.Routes in '..\src\IUS.Routes.pas',
  IUS.Tests.Smoke in 'IUS.Tests.Smoke.pas',
  DUnitX.TestFramework;

{$IFDEF TESTINSIGHT}
begin
  TestInsight.DUnitX.RunRegisteredTests;
end.
{$ELSE}
var
  LRunner: ITestRunner;
  LResults: IRunResults;
  LLogger: ITestLogger;
  LNUnitLogger : ITestLogger;
begin
  try
    TDUnitX.CheckCommandLine;
    LRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    LRunner.FailsOnNoAsserts := False;
    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      LLogger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      LRunner.AddLogger(LLogger);
    end;
    LNUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    LRunner.AddLogger(LNUnitLogger);
    LResults := LRunner.Execute;
    if not LResults.AllPassed then
      System.ExitCode := EXIT_ERRORS;
    {$IFNDEF CI}
    Write('Done.. press <Enter> to exit.');
    Readln;
    {$ENDIF}
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
{$ENDIF}
