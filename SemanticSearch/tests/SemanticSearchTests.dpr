program SemanticSearchTests;

{$IFNDEF TESTINSIGHT}{$APPTYPE CONSOLE}{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}TestInsight.DUnitX,{$ELSE}
  DUnitX.Loggers.Console,{$ENDIF}
  DUnitX.TestFramework,
  SS.TextChunker in '..\src\SS.TextChunker.pas',
  SS.Config in '..\src\SS.Config.pas',
  SS.Embedding in '..\src\SS.Embedding.pas',
  SS.VectorStore in '..\src\SS.VectorStore.pas',
  SS.ChatClient in '..\src\SS.ChatClient.pas',
  SS.TextChunker.Tests in 'SS.TextChunker.Tests.pas',
  SS.Config.Tests in 'SS.Config.Tests.pas',
  SS.VectorStore.Tests in 'SS.VectorStore.Tests.pas';

var
  LRunner: ITestRunner;
  LResults: IRunResults;
  LLogger: ITestLogger;

begin
  try
    TDUnitX.CheckCommandLine;
    LRunner := TDUnitX.CreateRunner;
    LLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LLogger);
    LRunner.FailsOnNoAsserts := True;

    LResults := LRunner.Execute;
    if not LResults.AllPassed then
      System.ExitCode := EXIT_ERRORS;
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      System.ExitCode := EXIT_ERRORS;
    end;
  end;
end.
