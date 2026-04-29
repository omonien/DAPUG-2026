{ -----------------------------------------------------------------------------
  /// <summary>
  ///   FormMain
  ///   FMX main form: PDF drop zone, indexed files list, query input,
  ///   answer display, and detailed progress logging.
  /// </summary>
  /// <remarks>
  ///   Thin shell over TRAGEngine. File drops and query submissions are
  ///   forwarded to the engine; results are rendered in a memo.
  ///   Indexing runs in a background thread with live progress updates
  ///   shown in the answer memo and a progress bar.
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
  FMX.Memo, FMX.Edit, FMX.ListBox, FMX.ScrollBox, FMX.Memo.Types,
  FMX.Controls.Presentation,
  SS.Config, SS.RAGEngine;

type
  TMainForm = class(TForm)
    LayoutTop: TLayout;
    LayoutBottom: TLayout;
    DropZone: TRectangle;
    LabelDropTitle: TLabel;
    LabelDropHint: TLabel;
    EditQuery: TEdit;
    ButtonSearch: TButton;
    MemoAnswer: TMemo;
    LabelStatus: TLabel;
    LabelFilesTitle: TLabel;
    ListBoxFiles: TListBox;
    ButtonReindex: TButton;
    Splitter: TSplitter;
    LayoutCenter: TLayout;
    LayoutLeft: TLayout;
    ProgressBar: TProgressBar;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure DropZoneDragOver(Sender: TObject; const Data: TDragObject; const Point: TPointF; var Operation: TDragOperation);
    procedure DropZoneDragDrop(Sender: TObject; const Data: TDragObject; const Point: TPointF);
    procedure ButtonSearchClick(Sender: TObject);
    procedure EditQueryKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure ButtonReindexClick(Sender: TObject);
  private
    FConfig: TConfig;
    FEngine: TRAGEngine;
    FBusy: Boolean;
    procedure SetBusy(AValue: Boolean);
    procedure LoadAppConfig;
    procedure RefreshFileList;
    procedure CopyPdfToVar(const ASourcePath: string);
    procedure StartIndexThread(const AFilePath: string);
    procedure StartQueryThread(const AQuestion: string);
    procedure StartReindexThread;
    procedure ShowStatus(const AMsg: string);
    procedure LogProgress(const AMsg: string);
    procedure ShowProgress(ACurrent, ATotal: Integer);
    procedure HideProgress;
    procedure RunIndex(const AFilePath: string);
    procedure RunQuery(const AQuestion: string);
    procedure RunReindex(const ADir: string);
  end;

  TWorkerThread = class(TThread)
  private
    FWorkProc: TThreadProcedure;
  protected
    procedure Execute; override;
  public
    constructor Create(AWorkProc: TThreadProcedure);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

uses
  System.IOUtils, System.DateUtils;

{ TWorkerThread }

constructor TWorkerThread.Create(AWorkProc: TThreadProcedure);
begin
  inherited Create(True);
  FWorkProc := AWorkProc;
  FreeOnTerminate := True;
end;

procedure TWorkerThread.Execute;
begin
  FWorkProc;
end;

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  LMsg: string;
begin
  FBusy := False;
  try
    LoadAppConfig;
    FEngine := TRAGEngine.Create(FConfig);
    RefreshFileList;
    ShowStatus(Format('Ready. %d chunks from %d files indexed.',
      [FEngine.GetChunkCount, Length(FEngine.GetIndexedFiles)]));
  except
    on E: Exception do
    begin
      LMsg := E.Message;
      FEngine := nil;
      ShowStatus('Error: ' + LMsg);
      MemoAnswer.Text := LMsg;
      SetBusy(True);
    end;
  end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FEngine);
end;

procedure TMainForm.LoadAppConfig;
var
  LConfigPath: string;
  LRoot: string;
  LFound: Boolean;
begin
  LRoot := ExtractFilePath(ParamStr(0));
  LFound := False;
  while not LFound do
  begin
    LConfigPath := TPath.Combine(LRoot, 'config.ini');
    if TFile.Exists(LConfigPath) then
    begin
      LFound := True;
      Break;
    end;
    LRoot := TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(LRoot));
    if LRoot = '' then Break;
  end;
  if not LFound then
    raise Exception.Create('config.ini not found. Copy config.ini.example to config.ini and fill in API keys.');
  FConfig := SS.Config.LoadConfig(LConfigPath);
end;

procedure TMainForm.RefreshFileList;
var
  LFiles: TArray<string>;
  LFile: string;
begin
  ListBoxFiles.Clear;
  if FEngine = nil then Exit;
  LFiles := FEngine.GetIndexedFiles;
  for LFile in LFiles do
    ListBoxFiles.Items.Add(LFile);
end;

procedure TMainForm.CopyPdfToVar(const ASourcePath: string);
var
  LDestDir, LDestPath: string;
begin
  LDestDir := ResolvePath(FConfig.PdfDir, '');
  if not TDirectory.Exists(LDestDir) then
    TDirectory.CreateDirectory(LDestDir);
  LDestPath := TPath.Combine(LDestDir, TPath.GetFileName(ASourcePath));
  if not SameText(ASourcePath, LDestPath) then
    TFile.Copy(ASourcePath, LDestPath, True);
end;

procedure TMainForm.SetBusy(AValue: Boolean);
begin
  FBusy := AValue;
  ButtonSearch.Enabled := not AValue;
  ButtonReindex.Enabled := not AValue;
  EditQuery.Enabled := not AValue;
  DropZone.HitTest := not AValue;
end;

procedure TMainForm.ShowStatus(const AMsg: string);
begin
  LabelStatus.Text := AMsg;
end;

procedure TMainForm.LogProgress(const AMsg: string);
begin
  MemoAnswer.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + AMsg);
  MemoAnswer.GoToTextEnd;
end;

procedure TMainForm.ShowProgress(ACurrent, ATotal: Integer);
begin
  ProgressBar.Visible := True;
  if ATotal > 0 then
  begin
    ProgressBar.Max := ATotal;
    ProgressBar.Value := ACurrent;
  end;
end;

procedure TMainForm.HideProgress;
begin
  ProgressBar.Visible := False;
  ProgressBar.Value := 0;
end;

procedure TMainForm.RunIndex(const AFilePath: string);
var
  LProgress: TIndexProgress;
  LErrMsg: string;
  LOk: Boolean;
begin
  LProgress :=
    procedure(AMsg: string; ACurrent, ATotal: Integer)
    begin
      TThread.Queue(nil,
        procedure
        begin
          LogProgress(AMsg);
          if ATotal > 0 then
            ShowProgress(ACurrent, ATotal)
          else
            HideProgress;
        end);
    end;

  LOk := False;
  LErrMsg := '';
  try
    FEngine.IndexPdf(AFilePath, LProgress);
    LOk := True;
  except
    on E: Exception do
      LErrMsg := E.Message;
  end;

  TThread.Queue(nil,
    procedure
    begin
      if LOk then
      begin
        LogProgress('Done. Index saved.');
        RefreshFileList;
        ShowStatus(Format('Ready. %d chunks from %d files indexed.',
          [FEngine.GetChunkCount, Length(FEngine.GetIndexedFiles)]));
      end
      else
      begin
        LogProgress('ERROR: ' + LErrMsg);
        ShowStatus('Error: ' + LErrMsg);
      end;
      HideProgress;
      SetBusy(False);
    end);
end;

procedure TMainForm.RunQuery(const AQuestion: string);
var
  LAnswer: string;
  LErrMsg: string;
  LOk: Boolean;
begin
  LOk := False;
  LErrMsg := '';
  LAnswer := '';
  try
    LAnswer := FEngine.Query(AQuestion);
    LOk := True;
  except
    on E: Exception do
      LErrMsg := E.Message;
  end;

  TThread.Queue(nil,
    procedure
    begin
      if LOk then
      begin
        MemoAnswer.Lines.Clear;
        MemoAnswer.Text := LAnswer;
        ShowStatus(Format('Ready. %d chunks from %d files indexed.',
          [FEngine.GetChunkCount, Length(FEngine.GetIndexedFiles)]));
      end
      else
      begin
        LogProgress('ERROR: ' + LErrMsg);
        ShowStatus('Error: ' + LErrMsg);
      end;
      HideProgress;
      SetBusy(False);
    end);
end;

procedure TMainForm.RunReindex(const ADir: string);
var
  LProgress: TIndexProgress;
  LErrMsg: string;
  LOk: Boolean;
begin
  LProgress :=
    procedure(AMsg: string; ACurrent, ATotal: Integer)
    begin
      TThread.Queue(nil,
        procedure
        begin
          LogProgress(AMsg);
          if ATotal > 0 then
            ShowProgress(ACurrent, ATotal)
          else
            HideProgress;
        end);
    end;

  LOk := False;
  LErrMsg := '';
  try
    FEngine.IndexDirectory(ADir, LProgress);
    LOk := True;
  except
    on E: Exception do
      LErrMsg := E.Message;
  end;

  TThread.Queue(nil,
    procedure
    begin
      if LOk then
      begin
        LogProgress('Done. Index saved.');
        RefreshFileList;
        ShowStatus(Format('Ready. %d chunks from %d files indexed.',
          [FEngine.GetChunkCount, Length(FEngine.GetIndexedFiles)]));
      end
      else
      begin
        LogProgress('ERROR: ' + LErrMsg);
        ShowStatus('Error: ' + LErrMsg);
      end;
      HideProgress;
      SetBusy(False);
    end);
end;

procedure TMainForm.StartIndexThread(const AFilePath: string);
var
  LFilePath: string;
  LThread: TWorkerThread;
begin
  LFilePath := AFilePath;
  SetBusy(True);
  MemoAnswer.Lines.Clear;
  LogProgress('Starting: ' + TPath.GetFileName(LFilePath));
  ShowStatus('Indexing...');
  LThread := TWorkerThread.Create(
    procedure
    begin
      RunIndex(LFilePath);
    end);
  LThread.Start;
end;

procedure TMainForm.StartQueryThread(const AQuestion: string);
var
  LQuestion: string;
  LThread: TWorkerThread;
begin
  LQuestion := AQuestion;
  SetBusy(True);
  MemoAnswer.Lines.Clear;
  LogProgress('Searching: ' + LQuestion);
  ShowStatus('Querying...');
  LThread := TWorkerThread.Create(
    procedure
    begin
      RunQuery(LQuestion);
    end);
  LThread.Start;
end;

procedure TMainForm.StartReindexThread;
var
  LDir: string;
  LThread: TWorkerThread;
begin
  LDir := ResolvePath(FConfig.PdfDir, '');
  SetBusy(True);
  MemoAnswer.Lines.Clear;
  LogProgress('Re-indexing: ' + LDir);
  ShowStatus('Re-indexing PDF directory...');
  LThread := TWorkerThread.Create(
    procedure
    begin
      RunReindex(LDir);
    end);
  LThread.Start;
end;

procedure TMainForm.DropZoneDragOver(Sender: TObject; const Data: TDragObject;
  const Point: TPointF; var Operation: TDragOperation);
var
  LFile: string;
begin
  if FBusy then
  begin
    Operation := TDragOperation.None;
    Exit;
  end;
  for LFile in Data.Files do
  begin
    if SameText(TPath.GetExtension(LFile), '.pdf') then
    begin
      Operation := TDragOperation.Move;
      Exit;
    end;
  end;
  Operation := TDragOperation.None;
end;

procedure TMainForm.DropZoneDragDrop(Sender: TObject; const Data: TDragObject;
  const Point: TPointF);
var
  LFile: string;
begin
  if FEngine = nil then Exit;
  for LFile in Data.Files do
  begin
    if SameText(TPath.GetExtension(LFile), '.pdf') then
    begin
      CopyPdfToVar(LFile);
      StartIndexThread(TPath.Combine(ResolvePath(FConfig.PdfDir, ''), TPath.GetFileName(LFile)));
      Exit;
    end;
  end;
end;

procedure TMainForm.ButtonSearchClick(Sender: TObject);
var
  LQuestion: string;
begin
  if FEngine = nil then Exit;
  LQuestion := Trim(EditQuery.Text);
  if LQuestion = '' then Exit;
  if FEngine.GetChunkCount = 0 then
  begin
    MemoAnswer.Text := 'No documents indexed yet. Drop PDF files onto the drop zone first.';
    Exit;
  end;
  StartQueryThread(LQuestion);
end;

procedure TMainForm.EditQueryKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  if (Key = vkReturn) and not FBusy then
    ButtonSearchClick(nil);
end;

procedure TMainForm.ButtonReindexClick(Sender: TObject);
begin
  if FEngine = nil then Exit;
  StartReindexThread;
end;

end.
