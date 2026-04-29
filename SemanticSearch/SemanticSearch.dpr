program SemanticSearch;

uses
  System.StartUpCopy,
  FMX.Forms,
  FormMain in 'src\FormMain.pas' {MainForm},
  SS.Config in 'src\SS.Config.pas',
  SS.TextChunker in 'src\SS.TextChunker.pas',
  SS.Embedding in 'src\SS.Embedding.pas',
  SS.VectorStore in 'src\SS.VectorStore.pas',
  SS.PdfExtractor in 'src\SS.PdfExtractor.pas',
  SS.ChatClient in 'src\SS.ChatClient.pas',
  SS.RAGEngine in 'src\SS.RAGEngine.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
