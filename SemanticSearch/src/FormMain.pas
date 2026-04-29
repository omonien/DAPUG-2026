{ -----------------------------------------------------------------------------
  /// <summary>
  ///   FormMain
  ///   FMX main form: PDF drop zone, indexed files list, query input,
  ///   and answer display.
  /// </summary>
  /// <remarks>
  ///   Thin shell over TRAGEngine. File drops and query submissions are
  ///   forwarded to the engine; results are rendered in a memo.
  ///   Indexing runs in a background thread to keep the UI responsive.
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
  FMX.Memo, FMX.Edit, FMX.ListBox, FMX.ScrollBox,
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
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

uses
  System.IOUtils;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FBusy := False;
  LoadAppConfig;
  FEngine := TRAGEngine.Create(FConfig);
  RefreshFileList;
  ShowStatus(Format('Ready. %d chunks from %d files indexed.',
    [FEngine.GetChunkCount, Length(FEngine.GetIndexedFiles)]));
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FEngine);
end;

procedure TMainForm.LoadAppConfig;
var
  LConfigPath: string;
  LRoot: string;
begin
  LRoot := ExtractFilePath(ParamStr(0));
  LConfigPath := TPath.Combine(LRoot, 'config.ini');
  if not TFile.Exists(LConfigPath) then
  begin
    LRoot := TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(LRoot));
    LConfigPath := TPath.Combine(LRoot, 'config.ini');
  end;
  if not TFile.Exists(LConfigPath) then
  begin
    LRoot := TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(LRoot));
    LConfigPath := TPath.Combine(LRoot, 'config.ini');
  end;
  if not TFile.Exists(LConfigPath) then
    raise Exception.Create('config.ini not found. Copy config.ini.example to config.ini and fill in API keys.');
  FConfig := SS.Config.LoadConfig(LConfigPath);
end;

procedure TMainForm.RefreshFileList;
var
  LFiles: TArray<string>;
  LFile: string;
begin
  ListBoxFiles.Clear;
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

procedure TMainForm.StartIndexThread(const AFilePath: string);
var
  LThread: TThread;
  LFilePath: string;
begin
  LFilePath := AFilePath;
  SetBusy(True);
  ShowStatus('Indexing...');
  LThread := TThread.CreateAnonymousThread(
    procedure
    var
      LErrMsg: string;
      LOk: Boolean;
    begin
      LOk := False;
      LErrMsg := '';
      try
        FEngine.IndexPdf(LFilePath, nil);
        LOk := True;
      except
        on E: Exception do
          LErrMsg := E.Message;
      end;
      TThread.Synchronize(nil,
        procedure
        begin
          if LOk then
          begin
            RefreshFileList;
            ShowStatus(Format('Ready. %d chunks from %d files indexed.',
              [FEngine.GetChunkCount, Length(FEngine.GetIndexedFiles)]));
          end
          else
            ShowStatus('Error: ' + LErrMsg);
          SetBusy(False);
        end);
    end);
  LThread.FreeOnTerminate := True;
  LThread.Start;
end;

procedure TMainForm.StartQueryThread(const AQuestion: string);
var
  LThread: TThread;
  LQuestion: string;
begin
  LQuestion := AQuestion;
  SetBusy(True);
  MemoAnswer.Text := 'Searching...';
  ShowStatus('Querying...');
  LThread := TThread.CreateAnonymousThread(
    procedure
    var
      LAnswer: string;
      LErrMsg: string;
      LOk: Boolean;
    begin
      LOk := False;
      LErrMsg := '';
      LAnswer := '';
      try
        LAnswer := FEngine.Query(LQuestion);
        LOk := True;
      except
        on E: Exception do
          LErrMsg := E.Message;
      end;
      TThread.Synchronize(nil,
        procedure
        begin
          if LOk then
          begin
            MemoAnswer.Text := LAnswer;
            ShowStatus(Format('Ready. %d chunks from %d files indexed.',
              [FEngine.GetChunkCount, Length(FEngine.GetIndexedFiles)]));
          end
          else
          begin
            MemoAnswer.Text := 'Error: ' + LErrMsg;
            ShowStatus('Error: ' + LErrMsg);
          end;
          SetBusy(False);
        end);
    end);
  LThread.FreeOnTerminate := True;
  LThread.Start;
end;

procedure TMainForm.StartReindexThread;
var
  LThread: TThread;
  LDir: string;
begin
  LDir := ResolvePath(FConfig.PdfDir, '');
  SetBusy(True);
  ShowStatus('Re-indexing PDF directory...');
  LThread := TThread.CreateAnonymousThread(
    procedure
    var
      LErrMsg: string;
      LOk: Boolean;
    begin
      LOk := False;
      LErrMsg := '';
      try
        FEngine.IndexDirectory(LDir, nil);
        LOk := True;
      except
        on E: Exception do
          LErrMsg := E.Message;
      end;
      TThread.Synchronize(nil,
        procedure
        begin
          if LOk then
          begin
            RefreshFileList;
            ShowStatus(Format('Ready. %d chunks from %d files indexed.',
              [FEngine.GetChunkCount, Length(FEngine.GetIndexedFiles)]));
          end
          else
            ShowStatus('Error: ' + LErrMsg);
          SetBusy(False);
        end);
    end);
  LThread.FreeOnTerminate := True;
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
  StartReindexThread;
end;

end.
