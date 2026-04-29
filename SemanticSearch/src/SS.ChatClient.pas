{ -----------------------------------------------------------------------------
  /// <summary>
  ///   SS.ChatClient
  ///   Calls an OpenAI-compatible /chat/completions endpoint with an
  ///   optional RAG context and returns the assistant's reply.
  /// </summary>
  /// <remarks>
  ///   Works with OpenAI, Azure OpenAI, Ollama, LM Studio, or any
  ///   server that exposes the standard chat completions API.
  /// </remarks>
  /// <copyright>
  ///   Copyright (c) 2026 Olaf Monien. MIT License.
  /// </copyright>
  ----------------------------------------------------------------------------- }
unit SS.ChatClient;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient;

type
  TChatClient = class
  strict private
    FApiKey: string;
    FModel: string;
    FBaseUrl: string;
    FMaxTokens: Integer;
    function BuildRequestBody(const ASystemPrompt, AUserMessage: string): string;
    function ParseContent(const AResponseBody: string): string;
  public
    constructor Create(const AApiKey, AModel, ABaseUrl: string; AMaxTokens: Integer = 1024);
    function Chat(const ASystemPrompt, AUserMessage: string): string;
    function ChatWithRAG(const AQuestion: string;
      const AContextChunks: TArray<string>;
      ATopK: Integer): string;
  end;

implementation

constructor TChatClient.Create(const AApiKey, AModel, ABaseUrl: string;
  AMaxTokens: Integer);
begin
  inherited Create;
  FApiKey := AApiKey;
  FModel := AModel;
  FBaseUrl := ABaseUrl.TrimRight(['/']);
  FMaxTokens := AMaxTokens;
end;

function TChatClient.BuildRequestBody(const ASystemPrompt, AUserMessage: string): string;
var
  LRoot, LSystemMsg, LUserMsg: TJSONObject;
  LMessages: TJSONArray;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('model', FModel);
    LRoot.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));
    LRoot.AddPair('temperature', TJSONNumber.Create(0.3));

    LMessages := TJSONArray.Create;

    LSystemMsg := TJSONObject.Create;
    LSystemMsg.AddPair('role', 'system');
    LSystemMsg.AddPair('content', ASystemPrompt);
    LMessages.AddElement(LSystemMsg);

    LUserMsg := TJSONObject.Create;
    LUserMsg.AddPair('role', 'user');
    LUserMsg.AddPair('content', AUserMessage);
    LMessages.AddElement(LUserMsg);

    LRoot.AddPair('messages', LMessages);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TChatClient.ParseContent(const AResponseBody: string): string;
var
  LRoot, LChoice, LMessage: TJSONObject;
  LChoices: TJSONArray;
begin
  LRoot := TJSONObject.ParseJSONValue(AResponseBody) as TJSONObject;
  if LRoot = nil then
    raise Exception.Create('Chat response is not valid JSON');
  try
    LChoices := LRoot.GetValue<TJSONArray>('choices');
    if (LChoices = nil) or (LChoices.Count = 0) then
      raise Exception.Create('No choices in chat response');
    LChoice := LChoices.Items[0] as TJSONObject;
    LMessage := LChoice.GetValue<TJSONObject>('message');
    Result := LMessage.GetValue<string>('content');
  finally
    LRoot.Free;
  end;
end;

function TChatClient.Chat(const ASystemPrompt, AUserMessage: string): string;
var
  LClient: TNetHTTPClient;
  LRequest: TNetHTTPRequest;
  LResponse: IHTTPResponse;
  LBody: TStringStream;
  LUrl: string;
begin
  LClient := TNetHTTPClient.Create(nil);
  LRequest := TNetHTTPRequest.Create(nil);
  LBody := TStringStream.Create(BuildRequestBody(ASystemPrompt, AUserMessage), TEncoding.UTF8);
  try
    LClient.ConnectionTimeout := 30000;
    LClient.ResponseTimeout := 120000;
    LRequest.Client := LClient;
    LRequest.CustomHeaders['Authorization'] := 'Bearer ' + FApiKey;
    LRequest.CustomHeaders['Content-Type'] := 'application/json';
    LUrl := FBaseUrl + '/chat/completions';
    try
      LResponse := LRequest.Post(LUrl, LBody);
    except
      on E: ENetHTTPClientException do
        raise Exception.Create('Chat network error: ' + E.Message);
    end;
    if LResponse.StatusCode <> 200 then
      raise Exception.CreateFmt('Chat API error %d: %s',
        [LResponse.StatusCode, Copy(LResponse.ContentAsString(TEncoding.UTF8), 1, 500)]);
    Result := ParseContent(LResponse.ContentAsString(TEncoding.UTF8));
  finally
    LBody.Free;
    LRequest.Free;
    LClient.Free;
  end;
end;

function TChatClient.ChatWithRAG(const AQuestion: string;
  const AContextChunks: TArray<string>;
  ATopK: Integer): string;
var
  LBuilder: TStringBuilder;
  LSystemPrompt: string;
  LChunk: string;
  I: Integer;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.AppendLine('You are a helpful assistant that answers questions based on the provided context.');
    LBuilder.AppendLine('Use only the information from the context to answer. If the context does not contain');
    LBuilder.AppendLine('enough information to answer the question, say so honestly.');
    LBuilder.AppendLine;
    LBuilder.AppendLine('Context:');
    I := 0;
    for LChunk in AContextChunks do
    begin
      Inc(I);
      LBuilder.AppendLine(Format('[%d] %s', [I, LChunk]));
    end;
    LSystemPrompt := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
  Result := Chat(LSystemPrompt, AQuestion);
end;

end.
