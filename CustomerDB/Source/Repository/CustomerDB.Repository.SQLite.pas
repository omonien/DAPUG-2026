unit CustomerDB.Repository.SQLite;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Stan.Param,
  FireDAC.DApt,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs,
  CustomerDB.Model.Customer,
  CustomerDB.Model.Order,
  CustomerDB.Repository.Interfaces;

type
  TSQLiteCustomerRepository = class(TInterfacedObject, ICustomerRepository)
  private
    FConnection: TFDConnection;
  public
    constructor Create(aConnection: TFDConnection);
    function GetAll: TObjectList<TCustomer>;
    function GetById(aId: Integer): TCustomer;
    function Search(const aFilter: string): TObjectList<TCustomer>;
    function Insert(aCustomer: TCustomer): Integer;
    procedure Update(aCustomer: TCustomer);
    procedure Delete(aId: Integer);
  end;

  TSQLiteOrderRepository = class(TInterfacedObject, IOrderRepository)
  private
    FConnection: TFDConnection;
  public
    constructor Create(aConnection: TFDConnection);
    function GetByCustomerId(aCustomerId: Integer): TObjectList<TOrder>;
    function GetOrderLines(aOrderId: Integer): TObjectList<TOrderLine>;
  end;

implementation

{ TSQLiteCustomerRepository }

constructor TSQLiteCustomerRepository.Create(aConnection: TFDConnection);
begin
  inherited Create;
  FConnection := aConnection;
end;

function SQLiteDateToDateTime(aField: TField): TDateTime;
var
  lStr: string;
  lFmt: TFormatSettings;
begin
  lStr := aField.AsString;
  if lStr.IsEmpty then
    Exit(0);
  lFmt := TFormatSettings.Create;
  lFmt.DateSeparator := '-';
  lFmt.ShortDateFormat := 'yyyy-mm-dd';
  lFmt.TimeSeparator := ':';
  lFmt.ShortTimeFormat := 'hh:nn:ss';
  Result := StrToDateTimeDef(lStr, 0, lFmt);
end;

function TSQLiteCustomerRepository.GetAll: TObjectList<TCustomer>;
var
  lQuery: TFDQuery;
  lCustomer: TCustomer;
begin
  Result := TObjectList<TCustomer>.Create(True);
  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := FConnection;
    lQuery.SQL.Text := 'SELECT * FROM Customer ORDER BY LastName, FirstName';
    lQuery.Open;
    while not lQuery.Eof do
    begin
      lCustomer := TCustomer.Create;
      lCustomer.Id := lQuery.FieldByName('Id').AsInteger;
      lCustomer.FirstName := lQuery.FieldByName('FirstName').AsString;
      lCustomer.LastName := lQuery.FieldByName('LastName').AsString;
      lCustomer.Company := lQuery.FieldByName('Company').AsString;
      lCustomer.Email := lQuery.FieldByName('Email').AsString;
      lCustomer.Phone := lQuery.FieldByName('Phone').AsString;
      lCustomer.Address := lQuery.FieldByName('Address').AsString;
      lCustomer.City := lQuery.FieldByName('City').AsString;
      lCustomer.ZipCode := lQuery.FieldByName('ZipCode').AsString;
      lCustomer.Country := lQuery.FieldByName('Country').AsString;
      lCustomer.CVR := lQuery.FieldByName('CVR').AsString;
      lCustomer.IsBusinessCustomer := lQuery.FieldByName('IsBusinessCustomer').AsInteger <> 0;
      lCustomer.CreatedAt := SQLiteDateToDateTime(lQuery.FieldByName('CreatedAt'));
      Result.Add(lCustomer);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
end;

function TSQLiteCustomerRepository.GetById(aId: Integer): TCustomer;
var
  lQuery: TFDQuery;
begin
  Result := nil;
  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := FConnection;
    lQuery.SQL.Text := 'SELECT * FROM Customer WHERE Id = :Id';
    lQuery.ParamByName('Id').AsInteger := aId;
    lQuery.Open;
    if not lQuery.Eof then
    begin
      Result := TCustomer.Create;
      Result.Id := lQuery.FieldByName('Id').AsInteger;
      Result.FirstName := lQuery.FieldByName('FirstName').AsString;
      Result.LastName := lQuery.FieldByName('LastName').AsString;
      Result.Company := lQuery.FieldByName('Company').AsString;
      Result.Email := lQuery.FieldByName('Email').AsString;
      Result.Phone := lQuery.FieldByName('Phone').AsString;
      Result.Address := lQuery.FieldByName('Address').AsString;
      Result.City := lQuery.FieldByName('City').AsString;
      Result.ZipCode := lQuery.FieldByName('ZipCode').AsString;
      Result.Country := lQuery.FieldByName('Country').AsString;
      Result.CVR := lQuery.FieldByName('CVR').AsString;
      Result.IsBusinessCustomer := lQuery.FieldByName('IsBusinessCustomer').AsInteger <> 0;
      Result.CreatedAt := Now;
    end;
  finally
    lQuery.Free;
  end;
end;

function TSQLiteCustomerRepository.Search(const aFilter: string): TObjectList<TCustomer>;
var
  lQuery: TFDQuery;
  lCustomer: TCustomer;
begin
  Result := TObjectList<TCustomer>.Create(True);
  if aFilter.Trim.IsEmpty then
  begin
    Result.Free;
    Result := GetAll;
    Exit;
  end;

  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := FConnection;
    lQuery.SQL.Text :=
      'SELECT * FROM Customer ' +
      'WHERE FirstName LIKE :Filter ' +
      'OR LastName LIKE :Filter ' +
      'OR Company LIKE :Filter ' +
      'OR Email LIKE :Filter ' +
      'ORDER BY LastName, FirstName';
    lQuery.ParamByName('Filter').AsString := '%' + aFilter + '%';
    lQuery.Open;
    while not lQuery.Eof do
    begin
      lCustomer := TCustomer.Create;
      lCustomer.Id := lQuery.FieldByName('Id').AsInteger;
      lCustomer.FirstName := lQuery.FieldByName('FirstName').AsString;
      lCustomer.LastName := lQuery.FieldByName('LastName').AsString;
      lCustomer.Company := lQuery.FieldByName('Company').AsString;
      lCustomer.Email := lQuery.FieldByName('Email').AsString;
      lCustomer.Phone := lQuery.FieldByName('Phone').AsString;
      lCustomer.Address := lQuery.FieldByName('Address').AsString;
      lCustomer.City := lQuery.FieldByName('City').AsString;
      lCustomer.ZipCode := lQuery.FieldByName('ZipCode').AsString;
      lCustomer.Country := lQuery.FieldByName('Country').AsString;
      lCustomer.CVR := lQuery.FieldByName('CVR').AsString;
      lCustomer.IsBusinessCustomer := lQuery.FieldByName('IsBusinessCustomer').AsInteger <> 0;
      lCustomer.CreatedAt := SQLiteDateToDateTime(lQuery.FieldByName('CreatedAt'));
      Result.Add(lCustomer);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
end;

function TSQLiteCustomerRepository.Insert(aCustomer: TCustomer): Integer;
begin
  FConnection.ExecSQL(
    'INSERT INTO Customer (FirstName, LastName, Company, Email, Phone, Address, City, ZipCode, Country, CVR, IsBusinessCustomer) ' +
    'VALUES (:fn, :ln, :co, :em, :ph, :ad, :ci, :zp, :ct, :cvr, :biz)',
    [aCustomer.FirstName, aCustomer.LastName, aCustomer.Company, aCustomer.Email,
     aCustomer.Phone, aCustomer.Address, aCustomer.City, aCustomer.ZipCode,
     aCustomer.Country, aCustomer.CVR, Ord(aCustomer.IsBusinessCustomer)]);
  Result := FConnection.GetLastAutoGenValue('');
end;

procedure TSQLiteCustomerRepository.Update(aCustomer: TCustomer);
begin
  FConnection.ExecSQL(
    'UPDATE Customer SET FirstName=:fn, LastName=:ln, Company=:co, Email=:em, ' +
    'Phone=:ph, Address=:ad, City=:ci, ZipCode=:zp, Country=:ct, CVR=:cvr, ' +
    'IsBusinessCustomer=:biz WHERE Id=:id',
    [aCustomer.FirstName, aCustomer.LastName, aCustomer.Company, aCustomer.Email,
     aCustomer.Phone, aCustomer.Address, aCustomer.City, aCustomer.ZipCode,
     aCustomer.Country, aCustomer.CVR, Ord(aCustomer.IsBusinessCustomer), aCustomer.Id]);
end;

procedure TSQLiteCustomerRepository.Delete(aId: Integer);
begin
  FConnection.ExecSQL('DELETE FROM OrderLine WHERE OrderId IN (SELECT Id FROM [Order] WHERE CustomerId=:id)', [aId]);
  FConnection.ExecSQL('DELETE FROM [Order] WHERE CustomerId=:id', [aId]);
  FConnection.ExecSQL('DELETE FROM Customer WHERE Id=:id', [aId]);
end;

{ TSQLiteOrderRepository }

constructor TSQLiteOrderRepository.Create(aConnection: TFDConnection);
begin
  inherited Create;
  FConnection := aConnection;
end;

function TSQLiteOrderRepository.GetByCustomerId(aCustomerId: Integer): TObjectList<TOrder>;
var
  lQuery: TFDQuery;
  lOrder: TOrder;
begin
  Result := TObjectList<TOrder>.Create(True);
  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := FConnection;
    lQuery.SQL.Text := 'SELECT * FROM [Order] WHERE CustomerId = :CustomerId ORDER BY OrderDate DESC';
    lQuery.ParamByName('CustomerId').AsInteger := aCustomerId;
    lQuery.Open;
    while not lQuery.Eof do
    begin
      lOrder := TOrder.Create;
      lOrder.Id := lQuery.FieldByName('Id').AsInteger;
      lOrder.CustomerId := lQuery.FieldByName('CustomerId').AsInteger;
      lOrder.OrderDate := SQLiteDateToDateTime(lQuery.FieldByName('OrderDate'));
      lOrder.Status := lQuery.FieldByName('Status').AsString;
      Result.Add(lOrder);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
end;

function TSQLiteOrderRepository.GetOrderLines(aOrderId: Integer): TObjectList<TOrderLine>;
var
  lQuery: TFDQuery;
  lLine: TOrderLine;
begin
  Result := TObjectList<TOrderLine>.Create(True);
  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := FConnection;
    lQuery.SQL.Text := 'SELECT * FROM OrderLine WHERE OrderId = :OrderId ORDER BY Id';
    lQuery.ParamByName('OrderId').AsInteger := aOrderId;
    lQuery.Open;
    while not lQuery.Eof do
    begin
      lLine := TOrderLine.Create;
      lLine.Id := lQuery.FieldByName('Id').AsInteger;
      lLine.OrderId := lQuery.FieldByName('OrderId').AsInteger;
      lLine.ProductName := lQuery.FieldByName('ProductName').AsString;
      lLine.Quantity := lQuery.FieldByName('Quantity').AsInteger;
      lLine.UnitPrice := lQuery.FieldByName('UnitPrice').AsFloat;
      Result.Add(lLine);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
end;

end.
