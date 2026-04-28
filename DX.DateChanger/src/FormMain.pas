{ -----------------------------------------------------------------------------
  /// <summary>
  ///   FMX main form: a single drop zone with status feedback. Thin shell
  ///   over TDateChangerService.
  /// </summary>
  /// <remarks>
  ///   Holds no parsing or OS-specific code. Drop events are forwarded to
  ///   the service; the resulting TDropResult is rendered as a transient
  ///   counter line that reverts after 5 s.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit FormMain;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  FMX.Forms, FMX.Controls, FMX.Types, FMX.Objects, FMX.StdCtrls, FMX.Layouts,
  DX.DateChanger.FileTime, DX.DateChanger.Service;

type
  TMainForm = class(TForm)
    DropZone: TRectangle;
    LabelTitle: TLabel;
    LabelHint: TLabel;
    LabelViewLog: TLabel;
    RevertTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure DropZoneDragOver(Sender: TObject; const Data: TDragObject; const Point: TPointF; var Operation: TDragOperation);
    procedure DropZoneDragDrop(Sender: TObject; const Data: TDragObject; const Point: TPointF);
    procedure RevertTimerTimer(Sender: TObject);
    procedure LabelViewLogClick(Sender: TObject);
  private
    FService: TDateChangerService;
    FLastLogPath: string;
    procedure ShowDefaultText;
    procedure ShowResult(const AResult: TDropResult);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

uses
{$IFDEF MSWINDOWS}
  Winapi.ShellAPI, Winapi.Windows,
{$ENDIF}
{$IFDEF MACOS}
  Macapi.Foundation, Macapi.AppKit, Macapi.Helpers,
{$ENDIF}
  FMX.Platform;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FService := TDateChangerService.Create(CreateFileTimeSetter);
  ShowDefaultText;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FService);
end;

procedure TMainForm.ShowDefaultText;
begin
  LabelTitle.Text := 'Drop files here';
  LabelHint.Text := 'Filenames starting with YYYY-MM-DD will have their date set to that day, 10:00 local time.';
  LabelViewLog.Visible := False;
end;

procedure TMainForm.ShowResult(const AResult: TDropResult);
var
  LText: string;
begin
  LText := Format('Last drop: %d processed '#$00B7' %d skipped', [AResult.Processed, AResult.Skipped]);
  if AResult.Errors > 0 then
    LText := LText + Format(' '#$00B7' %d error', [AResult.Errors]);
  LabelTitle.Text := LText;
  LabelHint.Text := '';
  LabelViewLog.Visible := AResult.Errors > 0;
  FLastLogPath := AResult.LogPath;
  RevertTimer.Enabled := False;
  RevertTimer.Enabled := True;
end;

procedure TMainForm.DropZoneDragOver(Sender: TObject; const Data: TDragObject;
  const Point: TPointF; var Operation: TDragOperation);
begin
  if Length(Data.Files) > 0 then
    Operation := TDragOperation.Move
  else
    Operation := TDragOperation.None;
end;

procedure TMainForm.DropZoneDragDrop(Sender: TObject; const Data: TDragObject;
  const Point: TPointF);
var
  LFiles: TArray<string>;
  LResult: TDropResult;
  LI: Integer;
begin
  // TDragObject.Files is 'array of string' (open array); copy into TArray<string>
  // so it is type-compatible with TDateChangerService.ProcessDrop(TArray<string>).
  SetLength(LFiles, Length(Data.Files));
  for LI := 0 to High(Data.Files) do
    LFiles[LI] := Data.Files[LI];
  LResult := FService.ProcessDrop(LFiles);
  ShowResult(LResult);
end;

procedure TMainForm.RevertTimerTimer(Sender: TObject);
begin
  RevertTimer.Enabled := False;
  ShowDefaultText;
end;

procedure TMainForm.LabelViewLogClick(Sender: TObject);
begin
  if FLastLogPath = '' then Exit;
{$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(FLastLogPath), nil, nil, SW_SHOWNORMAL);
{$ENDIF}
{$IFDEF MACOS}
  TNSWorkspace.Wrap(TNSWorkspace.OCClass.sharedWorkspace).openFile(StrToNSStr(FLastLogPath));
{$ENDIF}
end;

end.